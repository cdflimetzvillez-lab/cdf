import Link from 'next/link';
import { redirect } from 'next/navigation';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import CarteCle from '@/components/tresors/CarteCle';
import SelecteurParticipant from '@/components/tresors/SelecteurParticipant';
import { contexteJoueur, lireMissions, lireReglages } from '@/lib/tresors/db';

export default async function PageCle() {
  const ctx = await contexteJoueur();
  if (!ctx) redirect('/tresors-de-noel/acces');
  const [missions, r] = await Promise.all([lireMissions(), lireReglages()]);
  const actif = ctx.actif;

  return (
    <main className="tdn-page">
      <Entete titre="Ma clé" sur={actif?.participant.prenom ?? 'Compte'} />
      <div style={{ marginBottom: '1.2rem' }}>
        <SelecteurParticipant progressions={ctx.progressions} actifId={actif?.participant.id ?? null} marqueCle />
      </div>
      {actif?.cle ? (
        <>
          <CarteCle cle={actif.cle} prenom={actif.participant.prenom} marche={r.marche_texte} grande />
          <section className="tdn-carte" style={{ marginTop: '1.4rem' }}>
            <h2>Comment révéler mon trésor ?</h2>
            <ol className="tdn-liste-num">
              <li>Rendez-vous au {r.marche_texte.charAt(0).toLowerCase() + r.marche_texte.slice(1)}.</li>
              <li>Trouvez la <b>Salle aux Trésors</b> et son grand écran.</li>
              <li>Saisissez votre numéro de clé et votre code secret.</li>
              <li>Ouvrez votre trésor et récupérez votre lot auprès des bénévoles.</li>
            </ol>
          </section>
        </>
      ) : (
        <section className="tdn-carte tdn-centre">
          <svg className="tdn-cle-icone tdn-cle-icone-vide" viewBox="0 0 64 32" aria-hidden="true">
            <circle cx="13" cy="16" r="9" fill="none" stroke="currentColor" strokeWidth="3.5" />
            <path d="M22 16 H58 M50 16 v8 M42 16 v6" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" fill="none" />
          </svg>
          <h2>Pas encore de clé</h2>
          <p className="tdn-muted">{actif ? `${actif.participant.prenom} a résolu ${actif.missionsValidees.length} mystère${actif.missionsValidees.length > 1 ? 's' : ''} sur ${missions.length}.` : 'Aucun participant.'} La clé apparaîtra ici à la fin de l&apos;aventure.</p>
          <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Continuer l&apos;aventure</Link>
        </section>
      )}
      <NavTresors />
    </main>
  );
}
