import Link from 'next/link';
import { redirect } from 'next/navigation';
import EcranFin from '@/components/tresors/EcranFin';
import { contexteJoueur, lireMissions, lireReglages } from '@/lib/tresors/db';

export default async function PageFin() {
  const ctx = await contexteJoueur();
  if (!ctx) redirect('/tresors-de-noel/acces');
  const [missions, r] = await Promise.all([lireMissions(), lireReglages()]);
  const actif = ctx.actif;
  if (!actif?.cle) {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Pas encore…</h1>
        <p className="tdn-p">{actif?.participant.prenom ?? 'Ce participant'} n&apos;a pas encore résolu les {missions.length} mystères.</p>
        <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Retour à l&apos;aventure</Link>
      </main>
    );
  }
  return <EcranFin cle={actif.cle} prenom={actif.participant.prenom} nbMissions={missions.length} marche={r.marche_texte} />;
}
