import { createFileRoute } from "@tanstack/react-router";
import { ModuleAVenir } from "@/components/module-a-venir";

export const Route = createFileRoute("/_authenticated/pointage")({
  head: () => ({ meta: [{ title: "Pointage — BEGPHARMA" }, { name: "description", content: "Badge, pointage d'arrivée et de départ, y compris hors connexion." }] }),
  component: Page,
});

function Page() {
  return <ModuleAVenir titre="Pointage" description="Badge, pointage d'arrivée et de départ, y compris hors connexion." sprint="Sprint 3" />;
}
