'use client';
import Link from 'next/link';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import { useTresors } from '@/lib/tresors/store';
import { EVENEMENT, MISSIONS } from '@/lib/tresors/mock';

export default function PageAventure() {
  const { compte, participantActif, progressionActive, missionCourante, termine, setParticipantActif } = useTresors();
  const faites = progressionActive.missionsValidees.length;
  const mission = MISSIONS.find((m) => m.numero === missionCourante);

  return (
    <main className="tdn-page">
      <Entete titre={`Bonjour ${participantActif.prenom}`} sur="Mon aventure" />

      <section className="tdn-carte tdn-progression">
        <div className="tdn-sur">Progression</div>
        <div className="tdn-compteur"><b>{faites}</b> / {EVENEMENT.nbMissions} missions</div>
        <div className="tdn-barre"><i style={{ width: `${(faites / EVENEMENT.nbMissions) * 100}%` }} /></div>

        {compte.participants.length > 1 && (
          <div className="tdn-switch">
            <span className="tdn-sur">Participant actif</span>
            <div className="tdn-chips" role="radiogroup" aria-label="Changer de participant">
              {compte.participants.map((p) => (
                <button key={p.id} type="button" role="radio" aria-checked={p.id === participantActif.id}
                  className={p.id === participantActif.id ? 'on' : ''} onClick={() => setParticipantActif(p.id)}>
                  {p.prenom}
                </button>
              ))}
            </div>
          </div>
        )}
      </section>

      {termine ? (
        <section className="tdn-carte tdn-mission-carte tdn-or">
          <div className="tdn-sur">Aventure terminée</div>
          <h2 className="tdn-titre-fee">Les 12 mystères sont résolus</h2>
          <p>Votre clé virtuelle vous attend.</p>
          <Link href="/tresors-de-noel/cle" className="tdn-btn tdn-btn-nuit tdn-btn-large">Voir ma clé</Link>
        </section>
      ) : mission && (
        <section className="tdn-carte tdn-mission-carte">
          <div className="tdn-sur">Mission {mission.numero}</div>
          <h2 className="tdn-titre-fee">« {mission.titre} »</h2>
          <p className="tdn-lieu">📍 {mission.lieu}</p>
          <p>{mission.accroche}</p>
          <Link href={`/tresors-de-noel/mission/${mission.numero}`} className="tdn-btn tdn-btn-or tdn-btn-large">
            Découvrir l&apos;énigme
          </Link>
        </section>
      )}

      <section className="tdn-carte">
        <h2>Parcours</h2>
        <ol className="tdn-parcours">
          {MISSIONS.map((m) => {
            const ok = progressionActive.missionsValidees.includes(m.numero);
            const courante = m.numero === missionCourante;
            return (
              <li key={m.numero} className={ok ? 'ok' : courante ? 'now' : ''}>
                <span className="tdn-etape-n">{ok ? '✓' : m.numero}</span>
                <div>
                  <b>{m.titre}</b>
                  <small>{m.lieu}</small>
                </div>
                {ok && <Link href={`/tresors-de-noel/mission/${m.numero}`} className="tdn-mini-lien">Revoir</Link>}
              </li>
            );
          })}
        </ol>
      </section>
      <NavTresors />
    </main>
  );
}
