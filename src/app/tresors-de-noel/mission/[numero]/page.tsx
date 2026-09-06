import { notFound } from 'next/navigation';
import Entete from '@/components/tresors/Entete';
import Mission from '@/components/tresors/Mission';
import { MISSIONS } from '@/lib/tresors/mock';

export function generateStaticParams() {
  return MISSIONS.map((m) => ({ numero: String(m.numero) }));
}

export default async function PageMission({ params }: { params: Promise<{ numero: string }> }) {
  const { numero } = await params;
  const mission = MISSIONS.find((m) => m.numero === Number(numero));
  if (!mission) notFound();

  return (
    <main className="tdn-page">
      <Entete titre={mission.titre} sur={`Mission ${mission.numero}`} retour="/tresors-de-noel/aventure" />
      <Mission mission={mission} />
    </main>
  );
}
