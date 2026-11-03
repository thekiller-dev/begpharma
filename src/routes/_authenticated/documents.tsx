import { createFileRoute } from "@tanstack/react-router";
import { ModuleAVenir } from "@/components/module-a-venir";

export const Route = createFileRoute("/_authenticated/documents")({
  head: () => ({ meta: [{ title: "Documents — BEGPHARMA" }, { name: "description", content: "Gestion documentaire codifiée, versions et validation par le titulaire." }] }),
  component: Page,
});

function Page() {
  return <ModuleAVenir titre="Documents" description="Gestion documentaire codifiée, versions et validation par le titulaire." sprint="Sprint 4" />;
}
