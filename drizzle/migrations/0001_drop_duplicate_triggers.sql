-- Suppression des déclencheurs créés en double lors de la migration précédente
-- (les originaux, plus anciens, appelaient déjà les mêmes fonctions).
DROP TRIGGER IF EXISTS officines_audit ON public.officines;
DROP TRIGGER IF EXISTS officines_parametres_defaut ON public.officines;
DROP TRIGGER IF EXISTS officines_set_updated_at ON public.officines;
DROP TRIGGER IF EXISTS utilisateurs_officines_audit ON public.utilisateurs_officines;
DROP TRIGGER IF EXISTS utilisateurs_officines_set_updated_at ON public.utilisateurs_officines;
DROP TRIGGER IF EXISTS profils_set_updated_at ON public.profils;
DROP TRIGGER IF EXISTS sessions_appareils_set_updated_at ON public.sessions_appareils;
DROP TRIGGER IF EXISTS parametres_audit ON public.parametres;
DROP TRIGGER IF EXISTS parametres_versionner ON public.parametres;
DROP TRIGGER IF EXISTS journal_audit_immuable ON public.journal_audit;
