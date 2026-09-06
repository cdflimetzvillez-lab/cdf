'use client';
import Link from 'next/link';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import CarteCle from '@/components/tresors/CarteCle';
import { useTresors } from '@/lib/tresors/store';
import { EVENEMENT } from '@/lib/tresors/mock';

export default function PageCle() {
  const { compte, progressions, participantActif, setParticipantActif } = useTresors();
  const cle = progressions[participantActif.id]?.cle;
  const faites = progressions[participantActif.id]?.missionsValidees.length ?? 0;

  return (
    <main className="tdn-page">
      <Entete titre="Ma clé" sur={participantActif.prenom} />

      {compte.participants.length > 1 && (
        <div className="tdn-chips" style={{ marginBottom: '1.2rem' }}>
          {compte.participants.map((p) => (
            <button key={p.id} type="button" className={p.id === participantActif.id ? 'on' : ''} onClick={() => setParticipantActif(p.id)}>
              {p.prenom}{progressions[p.id]?.cle ? ' 🗝' : ''}
            </button>
          ))}
        </div>
      )}

      {cle ? (
        <>
          <CarteCle cle={cle} prenom={participantActif.prenom} grande />
          <section className="tdn-carte" style={{ marginTop: '1.4rem' }}>
            <h2>Comment révéler mon trésor ?</h2>
            <ol className="tdn-liste-num">
              <li>Rendez-vous au {EVENEMENT.marche.toLowerCase()}.</li>
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
          <p className="tdn-muted">{participantActif.prenom} a résolu {faites} mystère{faites > 1 ? 's' : ''} sur {EVENEMENT.nbMissions}. La clé apparaîtra ici à la fin de l&apos;aventure.</p>
          <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Continuer l&apos;aventure</Link>
        </section>
      )}
      <NavTresors />
    </main>
  );
}
