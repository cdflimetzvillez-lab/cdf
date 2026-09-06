import { redirect } from 'next/navigation';
import Entete from '@/components/tresors/Entete';
import FormInscription from '@/components/tresors/FormInscription';
import { compteCourant, lireReglages } from '@/lib/tresors/db';

export default async function PageInscription() {
  const [r, compte] = await Promise.all([lireReglages(), compteCourant()]);
  if (!r.inscriptions_ouvertes) {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Inscriptions fermées</h1>
        <p className="tdn-p">Les inscriptions ne sont pas ouvertes pour le moment.</p>
      </main>
    );
  }
  // Déjà un compte : on ajoute des participants depuis « Mon compte ».
  if (compte) redirect('/tresors-de-noel/compte');
  return (
    <main className="tdn-page">
      <Entete titre="Inscription" sur="Créer mon compte" />
      <FormInscription tarifAdulte={r.tarif_adulte_centimes} tarifEnfant={r.tarif_enfant_centimes} />
    </main>
  );
}
