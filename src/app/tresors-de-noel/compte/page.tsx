import Link from 'next/link';
import { redirect } from 'next/navigation';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import Participants from '@/components/tresors/Participants';
import { contexteJoueur, lireMissions, lireReglages } from '@/lib/tresors/db';
import { deconnecter } from '@/app/tresors-actions';

export default async function PageCompte() {
  const ctx = await contexteJoueur();
  if (!ctx) redirect('/tresors-de-noel/acces');
  const [missions, r] = await Promise.all([lireMissions(), lireReglages()]);

  return (
    <main className="tdn-page">
      <Entete titre="Mon compte" sur={`${ctx.compte.prenom} ${ctx.compte.nom}`} />
      <Participants progressions={ctx.progressions} actifId={ctx.actif?.participant.id ?? null} nbMissions={missions.length}
        tarifAdulte={r.tarif_adulte_centimes} tarifEnfant={r.tarif_enfant_centimes} inscriptionsOuvertes={r.inscriptions_ouvertes} />
      <section className="tdn-carte">
        <h2>Responsable</h2>
        <p>{ctx.compte.prenom} {ctx.compte.nom}</p>
        <p className="tdn-muted">{ctx.compte.email}{ctx.compte.telephone && ` · ${ctx.compte.telephone}`}</p>
      </section>
      <div className="tdn-cta"><Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Aller à mon aventure</Link></div>
      <form action={deconnecter} style={{ textAlign: 'center', marginTop: '2rem' }}>
        <button className="tdn-lien">Se déconnecter de ce téléphone</button>
      </form>
      <NavTresors />
    </main>
  );
}
