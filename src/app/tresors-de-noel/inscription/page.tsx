import Link from 'next/link';
import { redirect } from 'next/navigation';
import Entete from '@/components/tresors/Entete';
import FormInscription from '@/components/tresors/FormInscription';
import { compteCourant, lireReglages, placesPrises } from '@/lib/tresors/db';

export default async function PageInscription() {
  const [r, compte, prises] = await Promise.all([lireReglages(), compteCourant(), placesPrises()]);
  const restantes = Math.max(r.places_max - prises, 0);
  if (!r.inscriptions_ouvertes) {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Inscriptions fermées</h1>
        <p className="tdn-p">Les inscriptions ne sont pas ouvertes pour le moment.</p>
      </main>
    );
  }
  if (restantes <= 0) {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Complet</h1>
        <p className="tdn-p">Toutes les places ont été réservées. Merci pour votre enthousiasme !</p>
      </main>
    );
  }
  // Déjà un compte : on ajoute des participants depuis « Mon compte ».
  if (compte) redirect('/tresors-de-noel/compte');
  return (
    <main className="tdn-page">
      <Entete titre="Inscription" sur="Créer mon compte" />
      <p className="tdn-muted tdn-mini" style={{ marginBottom: '1rem' }}>Il reste {restantes} place{restantes > 1 ? 's' : ''}. En validant, vous acceptez le <Link href="/tresors-de-noel/reglement" className="tdn-lien">règlement du jeu</Link>.</p>
      <FormInscription tarifAdulte={r.tarif_adulte_centimes} tarifEnfant={r.tarif_enfant_centimes} />
    </main>
  );
}
