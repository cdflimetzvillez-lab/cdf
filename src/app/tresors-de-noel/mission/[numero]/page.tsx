import { notFound, redirect } from 'next/navigation';
import Entete from '@/components/tresors/Entete';
import Mission from '@/components/tresors/Mission';
import { contexteJoueur, lireMissions, publique } from '@/lib/tresors/db';

export default async function PageMission({ params }: { params: Promise<{ numero: string }> }) {
  const { numero } = await params;
  const ctx = await contexteJoueur();
  if (!ctx) redirect('/tresors-de-noel/acces');
  const missions = await lireMissions();
  const mission = missions.find((m) => m.numero === Number(numero));
  if (!mission || !ctx.actif) notFound();

  return (
    <main className="tdn-page">
      <Entete titre={mission.titre} sur={`Mission ${mission.numero}`} retour="/tresors-de-noel/aventure" />
      <Mission mission={publique(mission)} progressions={ctx.progressions} actifId={ctx.actif.participant.id} />
    </main>
  );
}
