import { createFileRoute } from "@tanstack/react-router";
import { ModuleAVenir } from "@/components/module-a-venir";

export const Route = createFileRoute("/_authenticated/echeances")({
  head: () => ({ meta: [{ title: "Échéances — BEGPHARMA" }, { name: "description", content: "Calendrier des échéances et notifications (e-mail, SMS)." }] }),
  component: Page,
});

function Page() {
  return <ModuleAVenir titre="Échéances" description="Calendrier des échéances et notifications (e-mail, SMS)." sprint="Sprint 6" />;
}
