import { createFileRoute } from "@tanstack/react-router";
import { ModuleAVenir } from "@/components/module-a-venir";

export const Route = createFileRoute("/_authenticated/modeles")({
  head: () => ({ meta: [{ title: "Modèles — BEGPHARMA" }, { name: "description", content: "Les 59 modèles réglementaires du Guide BPD prêts à remplir." }] }),
  component: Page,
});

function Page() {
  return <ModuleAVenir titre="Modèles" description="Les 59 modèles réglementaires du Guide BPD prêts à remplir." sprint="Sprint 5" />;
}
