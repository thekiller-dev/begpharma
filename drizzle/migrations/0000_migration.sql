-- ===== Types =====
CREATE TYPE public.role_officine AS ENUM (
  'promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq','comptable',
  'preparateur','caissier','magasinier','agent_entretien'
);

-- ===== Fonction updated_at =====
CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;

-- ===== Profils =====
CREATE TABLE public.profils (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nom_complet text NOT NULL DEFAULT '',
  telephone text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived boolean NOT NULL DEFAULT false
);
GRANT SELECT, INSERT, UPDATE ON public.profils TO authenticated;
GRANT ALL ON public.profils TO service_role;
ALTER TABLE public.profils ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER profils_updated BEFORE UPDATE ON public.profils FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profils(id, nom_complet)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'nom_complet', ''));
  RETURN NEW;
END $$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===== Officines =====
CREATE TABLE public.officines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  ville text,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived boolean NOT NULL DEFAULT false
);
GRANT SELECT, UPDATE ON public.officines TO authenticated;
GRANT ALL ON public.officines TO service_role;
ALTER TABLE public.officines ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER officines_updated BEFORE UPDATE ON public.officines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ===== Rattachements =====
CREATE TABLE public.utilisateurs_officines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  officine_id uuid NOT NULL REFERENCES public.officines(id),
  user_id uuid NOT NULL,
  role public.role_officine NOT NULL,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived boolean NOT NULL DEFAULT false,
  UNIQUE (officine_id, user_id)
);
GRANT SELECT ON public.utilisateurs_officines TO authenticated;
GRANT ALL ON public.utilisateurs_officines TO service_role;
ALTER TABLE public.utilisateurs_officines ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER uo_updated BEFORE UPDATE ON public.utilisateurs_officines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Rôles qui exigent la double authentification
CREATE OR REPLACE FUNCTION public.role_exige_mfa(_r public.role_officine) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT _r IN ('promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq','comptable')
$$;

-- Officines accessibles : rattachement actif ET (rôle sans MFA OU session aal2)
CREATE OR REPLACE FUNCTION public.user_officines() RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT uo.officine_id FROM public.utilisateurs_officines uo
  JOIN public.officines o ON o.id = uo.officine_id AND NOT o.archived
  WHERE uo.user_id = auth.uid() AND NOT uo.archived
    AND (NOT public.role_exige_mfa(uo.role) OR COALESCE(auth.jwt()->>'aal','aal1') = 'aal2')
$$;

CREATE OR REPLACE FUNCTION public.a_role(_officine uuid, _roles public.role_officine[]) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.utilisateurs_officines uo
    WHERE uo.user_id = auth.uid() AND uo.officine_id = _officine AND NOT uo.archived
      AND uo.role = ANY(_roles)
      AND _officine IN (SELECT public.user_officines())
  )
$$;

-- Statut MFA requis (lisible même en aal1 pour forcer l'enrôlement)
CREATE OR REPLACE FUNCTION public.mfa_requise() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.utilisateurs_officines
    WHERE user_id = auth.uid() AND NOT archived AND public.role_exige_mfa(role))
$$;

-- Policies
CREATE POLICY "profil: lecture soi" ON public.profils FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY "profil: maj soi" ON public.profils FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY "officines: lecture rattachées" ON public.officines FOR SELECT TO authenticated
  USING (id IN (SELECT public.user_officines()));
CREATE POLICY "officines: maj promoteur" ON public.officines FOR UPDATE TO authenticated
  USING (public.a_role(id, ARRAY['promoteur']::public.role_officine[]))
  WITH CHECK (public.a_role(id, ARRAY['promoteur']::public.role_officine[]));

CREATE POLICY "rattachements: lecture" ON public.utilisateurs_officines FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR officine_id IN (SELECT public.user_officines()));

-- ===== Journal d'audit (append-only) =====
CREATE TABLE public.journal_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  officine_id uuid,
  table_nom text NOT NULL,
  ligne_id text,
  action text NOT NULL,
  ancienne_valeur jsonb,
  nouvelle_valeur jsonb,
  user_id uuid,
  appareil text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX journal_audit_officine_idx ON public.journal_audit(officine_id, created_at DESC);
GRANT SELECT ON public.journal_audit TO authenticated;
GRANT SELECT, INSERT ON public.journal_audit TO service_role;
ALTER TABLE public.journal_audit ENABLE ROW LEVEL SECURITY;
CREATE POLICY "audit: lecture promoteur/pharmacien/rmq" ON public.journal_audit FOR SELECT TO authenticated
  USING (officine_id IS NOT NULL AND public.a_role(officine_id,
    ARRAY['promoteur','pharmacien_titulaire','rmq']::public.role_officine[]));

CREATE OR REPLACE FUNCTION public.journal_immuable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Le journal d''audit est inaltérable (% interdit)', TG_OP; END $$;
CREATE TRIGGER journal_no_update BEFORE UPDATE OR DELETE ON public.journal_audit
FOR EACH ROW EXECUTE FUNCTION public.journal_immuable();
CREATE TRIGGER journal_no_truncate BEFORE TRUNCATE ON public.journal_audit
FOR EACH STATEMENT EXECUTE FUNCTION public.journal_immuable();

CREATE OR REPLACE FUNCTION public.audit_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old jsonb := CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END;
  v_new jsonb := CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END;
  v_row jsonb := COALESCE(v_new, v_old);
  v_off uuid;
  v_ua text;
BEGIN
  v_off := CASE WHEN TG_TABLE_NAME = 'officines' THEN (v_row->>'id')::uuid
                ELSE NULLIF(v_row->>'officine_id','')::uuid END;
  BEGIN v_ua := current_setting('request.headers', true)::json->>'user-agent';
  EXCEPTION WHEN others THEN v_ua := NULL; END;
  INSERT INTO public.journal_audit(officine_id, table_nom, ligne_id, action, ancienne_valeur, nouvelle_valeur, user_id, appareil)
  VALUES (v_off, TG_TABLE_NAME, v_row->>'id', TG_OP, v_old, v_new, auth.uid(), v_ua);
  RETURN COALESCE(NEW, OLD);
END $$;

CREATE TRIGGER audit_officines AFTER INSERT OR UPDATE OR DELETE ON public.officines FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_uo AFTER INSERT OR UPDATE OR DELETE ON public.utilisateurs_officines FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();

-- ===== Paramètres =====
CREATE TABLE public.parametres (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  officine_id uuid NOT NULL REFERENCES public.officines(id),
  cle text NOT NULL,
  libelle text NOT NULL,
  type text NOT NULL CHECK (type IN ('texte','entier','booleen')),
  valeur jsonb NOT NULL,
  unite text,
  version integer NOT NULL DEFAULT 1,
  created_by uuid DEFAULT auth.uid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived boolean NOT NULL DEFAULT false,
  UNIQUE (officine_id, cle)
);
GRANT SELECT, UPDATE ON public.parametres TO authenticated;
GRANT ALL ON public.parametres TO service_role;
ALTER TABLE public.parametres ENABLE ROW LEVEL SECURITY;
CREATE POLICY "parametres: lecture" ON public.parametres FOR SELECT TO authenticated
  USING (officine_id IN (SELECT public.user_officines()));
CREATE POLICY "parametres: maj promoteur" ON public.parametres FOR UPDATE TO authenticated
  USING (public.a_role(officine_id, ARRAY['promoteur']::public.role_officine[]))
  WITH CHECK (public.a_role(officine_id, ARRAY['promoteur']::public.role_officine[]));

CREATE OR REPLACE FUNCTION public.parametres_versionner() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.cle <> OLD.cle OR NEW.type <> OLD.type OR NEW.officine_id <> OLD.officine_id THEN
    RAISE EXCEPTION 'Seule la valeur d''un paramètre peut être modifiée';
  END IF;
  IF (NEW.type = 'entier' AND jsonb_typeof(NEW.valeur) <> 'number')
     OR (NEW.type = 'booleen' AND jsonb_typeof(NEW.valeur) <> 'boolean')
     OR (NEW.type = 'texte' AND jsonb_typeof(NEW.valeur) <> 'string') THEN
    RAISE EXCEPTION 'Valeur incompatible avec le type %', NEW.type;
  END IF;
  NEW.version := OLD.version + 1;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
CREATE TRIGGER parametres_version BEFORE UPDATE ON public.parametres FOR EACH ROW EXECUTE FUNCTION public.parametres_versionner();
CREATE TRIGGER audit_parametres AFTER INSERT OR UPDATE OR DELETE ON public.parametres FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();

CREATE OR REPLACE FUNCTION public.parametres_defaut() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.parametres(officine_id, cle, libelle, type, valeur, unite) VALUES
   (NEW.id,'fuseau','Fuseau horaire','texte','"Africa/Porto-Novo"',NULL),
   (NEW.id,'devise','Devise','texte','"XOF"',NULL),
   (NEW.id,'delai_inactivite','Verrouillage après inactivité','entier','15','min'),
   (NEW.id,'tolerance_pointage','Tolérance de pointage','entier','10','min'),
   (NEW.id,'conservation_registres','Conservation des registres','entier','10','ans'),
   (NEW.id,'conservation_documents','Conservation des documents qualité','entier','5','ans'),
   (NEW.id,'conservation_stupefiants','Conservation registre stupéfiants','entier','40','ans'),
   (NEW.id,'seuil_alerte_echeance','Alerte avant échéance','entier','30','jours');
  RETURN NEW;
END $$;
CREATE TRIGGER officines_parametres AFTER INSERT ON public.officines FOR EACH ROW EXECUTE FUNCTION public.parametres_defaut();

-- ===== Appareils connectés =====
CREATE TABLE public.sessions_appareils (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid(),
  libelle text NOT NULL,
  derniere_activite timestamptz NOT NULL DEFAULT now(),
  revoquee boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  archived boolean NOT NULL DEFAULT false
);
GRANT SELECT, INSERT, UPDATE ON public.sessions_appareils TO authenticated;
GRANT ALL ON public.sessions_appareils TO service_role;
ALTER TABLE public.sessions_appareils ENABLE ROW LEVEL SECURITY;
CREATE POLICY "appareils: soi" ON public.sessions_appareils FOR ALL TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE TRIGGER sa_updated BEFORE UPDATE ON public.sessions_appareils FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ===== Création d'officine (amorçage : le créateur devient promoteur) =====
CREATE OR REPLACE FUNCTION public.creer_officine(_nom text, _ville text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Non authentifié'; END IF;
  IF length(trim(_nom)) < 2 THEN RAISE EXCEPTION 'Nom d''officine invalide'; END IF;
  INSERT INTO public.officines(nom, ville, created_by) VALUES (trim(_nom), NULLIF(trim(_ville),''), auth.uid()) RETURNING id INTO v_id;
  INSERT INTO public.utilisateurs_officines(officine_id, user_id, role, created_by) VALUES (v_id, auth.uid(), 'promoteur', auth.uid());
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.creer_officine(text,text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.creer_officine(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mfa_requise() TO authenticated;