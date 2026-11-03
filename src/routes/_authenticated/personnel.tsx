import { createFileRoute } from "@tanstack/react-router";
import { ModuleAVenir } from "@/components/module-a-venir";

export const Route = createFileRoute("/_authenticated/personnel")({
  head: () => ({ meta: [{ title: "Personnel — BEGPHARMA" }, { name: "description", content: "Fiches du personnel, contrats, habilitations et formations." }] }),
  component: Page,
});

function Page() {
  return <ModuleAVenir titre="Personnel" description="Fiches du personnel, contrats, habilitations et formations." sprint="Sprint 2" />;
}
