import { createFileRoute } from "@tanstack/react-router";
import { ModuleAVenir } from "@/components/module-a-venir";

export const Route = createFileRoute("/_authenticated/non-conformites")({
  head: () => ({ meta: [{ title: "Non-conformités — BEGPHARMA" }, { name: "description", content: "Déclaration des non-conformités et suivi des actions CAPA." }] }),
  component: Page,
});

function Page() {
  return <ModuleAVenir titre="Non-conformités" description="Déclaration des non-conformités et suivi des actions CAPA." sprint="Sprint 5" />;
}
