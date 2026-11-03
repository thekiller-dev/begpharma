CREATE TABLE public.employes (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), officine_id uuid NOT NULL REFERENCES public.officines(id), nom_complet text NOT NULL, telephone text, poste public.role_officine NOT NULL DEFAULT 'preparateur', date_embauche date, actif boolean NOT NULL DEFAULT true, created_by uuid DEFAULT auth.uid(), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), archived boolean NOT NULL DEFAULT false);
CREATE TABLE public.pointages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), officine_id uuid NOT NULL REFERENCES public.officines(id), employe_id uuid NOT NULL REFERENCES public.employes(id), type text NOT NULL CHECK (type IN ('arrivee','depart')), horodatage timestamptz NOT NULL DEFAULT now(), created_by uuid DEFAULT auth.uid(), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.documents (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), officine_id uuid NOT NULL REFERENCES public.officines(id), titre text NOT NULL, categorie text NOT NULL DEFAULT 'procedure', modele boolean NOT NULL DEFAULT false, contenu text NOT NULL DEFAULT '', version integer NOT NULL DEFAULT 1, statut text NOT NULL DEFAULT 'brouillon' CHECK (statut IN ('brouillon','a_valider','valide')), valide_par uuid, valide_le timestamptz, created_by uuid DEFAULT auth.uid(), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), archived boolean NOT NULL DEFAULT false);
CREATE TABLE public.non_conformites (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), officine_id uuid NOT NULL REFERENCES public.officines(id), titre text NOT NULL, description text NOT NULL DEFAULT '', gravite text NOT NULL DEFAULT 'mineure' CHECK (gravite IN ('mineure','majeure','critique')), statut text NOT NULL DEFAULT 'ouverte' CHECK (statut IN ('ouverte','en_cours','cloturee')), action_corrective text NOT NULL DEFAULT '', date_limite date, created_by uuid DEFAULT auth.uid(), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), archived boolean NOT NULL DEFAULT false);
CREATE TABLE public.echeances (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), officine_id uuid NOT NULL REFERENCES public.officines(id), titre text NOT NULL, categorie text NOT NULL DEFAULT 'autre', date_echeance date NOT NULL, fait boolean NOT NULL DEFAULT false, notes text NOT NULL DEFAULT '', created_by uuid DEFAULT auth.uid(), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), archived boolean NOT NULL DEFAULT false);

GRANT SELECT, INSERT, UPDATE ON public.employes, public.documents, public.non_conformites, public.echeances TO authenticated;
GRANT SELECT, INSERT ON public.pointages TO authenticated;
GRANT ALL ON public.employes, public.pointages, public.documents, public.non_conformites, public.echeances TO service_role;

ALTER TABLE public.employes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pointages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.non_conformites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.echeances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "employes: lecture" ON public.employes FOR SELECT TO authenticated USING (officine_id IN (SELECT public.user_officines()));
CREATE POLICY "employes: ajout direction" ON public.employes FOR INSERT TO authenticated WITH CHECK (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint']::public.role_officine[]));
CREATE POLICY "employes: maj direction" ON public.employes FOR UPDATE TO authenticated USING (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint']::public.role_officine[])) WITH CHECK (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint']::public.role_officine[]));

CREATE POLICY "pointages: lecture" ON public.pointages FOR SELECT TO authenticated USING (officine_id IN (SELECT public.user_officines()));
CREATE POLICY "pointages: ajout membre" ON public.pointages FOR INSERT TO authenticated WITH CHECK (officine_id IN (SELECT public.user_officines()));

CREATE POLICY "documents: lecture" ON public.documents FOR SELECT TO authenticated USING (officine_id IN (SELECT public.user_officines()));
CREATE POLICY "documents: ajout qualite" ON public.documents FOR INSERT TO authenticated WITH CHECK (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[]));
CREATE POLICY "documents: maj qualite" ON public.documents FOR UPDATE TO authenticated USING (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[])) WITH CHECK (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[]));

CREATE POLICY "nc: lecture" ON public.non_conformites FOR SELECT TO authenticated USING (officine_id IN (SELECT public.user_officines()));
CREATE POLICY "nc: declaration membre" ON public.non_conformites FOR INSERT TO authenticated WITH CHECK (officine_id IN (SELECT public.user_officines()));
CREATE POLICY "nc: maj qualite" ON public.non_conformites FOR UPDATE TO authenticated USING (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[])) WITH CHECK (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[]));

CREATE POLICY "echeances: lecture" ON public.echeances FOR SELECT TO authenticated USING (officine_id IN (SELECT public.user_officines()));
CREATE POLICY "echeances: ajout direction" ON public.echeances FOR INSERT TO authenticated WITH CHECK (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[]));
CREATE POLICY "echeances: maj direction" ON public.echeances FOR UPDATE TO authenticated USING (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[])) WITH CHECK (public.a_role(officine_id, ARRAY['promoteur','pharmacien_titulaire','pharmacien_adjoint','rmq']::public.role_officine[]));

CREATE TRIGGER employes_updated BEFORE UPDATE ON public.employes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER documents_updated BEFORE UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER nc_updated BEFORE UPDATE ON public.non_conformites FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER echeances_updated BEFORE UPDATE ON public.echeances FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER audit_employes AFTER INSERT OR UPDATE ON public.employes FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_pointages AFTER INSERT ON public.pointages FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_documents AFTER INSERT OR UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_nc AFTER INSERT OR UPDATE ON public.non_conformites FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_echeances AFTER INSERT OR UPDATE ON public.echeances FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();