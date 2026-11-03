-- Recréation des déclencheurs perdus lors du remix (les fonctions existent déjà).

-- Profil créé à l'inscription
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Paramètres par défaut à la création d'une officine
CREATE TRIGGER officines_parametres_defaut
  AFTER INSERT ON public.officines
  FOR EACH ROW EXECUTE FUNCTION public.parametres_defaut();

-- updated_at automatique
CREATE TRIGGER officines_set_updated_at
  BEFORE UPDATE ON public.officines
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER utilisateurs_officines_set_updated_at
  BEFORE UPDATE ON public.utilisateurs_officines
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER profils_set_updated_at
  BEFORE UPDATE ON public.profils
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER sessions_appareils_set_updated_at
  BEFORE UPDATE ON public.sessions_appareils
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Versionnement des paramètres (contrôle de cohérence + version + 1)
CREATE TRIGGER parametres_versionner
  BEFORE UPDATE ON public.parametres
  FOR EACH ROW EXECUTE FUNCTION public.parametres_versionner();

-- Journal d'audit : insertion automatique sur les tables rattachées à une officine
CREATE TRIGGER officines_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.officines
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER utilisateurs_officines_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.utilisateurs_officines
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER parametres_audit
  AFTER INSERT OR UPDATE OR DELETE ON public.parametres
  FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();

-- Journal d'audit inaltérable
CREATE TRIGGER journal_audit_immuable
  BEFORE UPDATE OR DELETE ON public.journal_audit
  FOR EACH ROW EXECUTE FUNCTION public.journal_immuable();
