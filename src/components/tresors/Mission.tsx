'use client';
import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import BlocMission from './BlocMission';
import Indices from './Indices';
import { useTresors } from '@/lib/tresors/store';
import type { Mission as MissionT } from '@/lib/tresors/types';

const normaliser = (s: string) => s.trim().toLowerCase().replace(/\s+/g, ' ');

/** Composant générique d'une mission : contenu, question, validation multi-participants, indices. */
export default function Mission({ mission }: { mission: MissionT }) {
  const router = useRouter();
  const { compte, progressions, participantActif, validerMission } = useTresors();
  const dejaFaite = progressions[participantActif.id]?.missionsValidees.includes(mission.numero) ?? false;

  const [reponse, setReponse] = useState('');
  const [choix, setChoix] = useState<number | null>(null);
  const [erreur, setErreur] = useState(false);
  const [reussi, setReussi] = useState(false);
  const [aTermine, setATermine] = useState(false);

  // Par défaut, on coche tous les participants qui n'ont pas encore validé cette mission.
  const [selection, setSelection] = useState<string[]>(() =>
    compte.participants
      .filter((p) => !(progressions[p.id]?.missionsValidees.includes(mission.numero)))
      .map((p) => p.id)
  );

  const q = mission.question;

  function verifier() {
    let ok = false;
    if (q.type === 'choix') ok = choix === q.bonneReponse;
    else ok = q.reponses.map(normaliser).includes(normaliser(reponse));
    if (!ok) { setErreur(true); return; }
    setErreur(false);
    const termines = validerMission(mission.numero, selection);
    setATermine(termines.includes(participantActif.id));
    setReussi(true);
  }

  function continuer() {
    router.push(aTermine ? '/tresors-de-noel/fin' : '/tresors-de-noel/aventure');
  }

  if (reussi) {
    return (
      <section className="tdn-carte tdn-reussite">
        <div className="tdn-eclat" aria-hidden="true">✦</div>
        <h2 className="tdn-titre-fee">Mission accomplie !</h2>
        <p>{aTermine ? 'Vous venez de résoudre le dernier mystère…' : 'Vous avez débloqué la mission suivante.'}</p>
        <p className="tdn-muted tdn-mini">
          Validée pour : {compte.participants.filter((p) => selection.includes(p.id)).map((p) => p.prenom).join(', ') || 'personne'}
        </p>
        <button className="tdn-btn tdn-btn-or tdn-btn-large" onClick={continuer}>Continuer</button>
      </section>
    );
  }

  return (
    <>
      <section className="tdn-carte">
        <p className="tdn-lieu">📍 {mission.lieu}</p>
        {mission.blocs.map((b, i) => <BlocMission key={i} bloc={b} />)}
      </section>

      <section className="tdn-carte">
        <div className="tdn-sur">Question</div>
        <p className="tdn-question">{q.intitule}</p>

        {q.type === 'texte' && (
          <div className="tdn-champ">
            <label htmlFor="rep" className="tdn-sr">Réponse</label>
            <input id="rep" placeholder={q.placeholder ?? 'Entrer la réponse'} value={reponse}
              onChange={(e) => { setReponse(e.target.value); setErreur(false); }}
              onKeyDown={(e) => e.key === 'Enter' && verifier()} autoCapitalize="none" />
          </div>
        )}
        {q.type === 'code' && (
          <div className="tdn-champ">
            <label htmlFor="rep" className="tdn-sr">Code</label>
            <input id="rep" className="tdn-code-input" inputMode="numeric" maxLength={q.longueur}
              placeholder={'•'.repeat(q.longueur)} value={reponse}
              onChange={(e) => { setReponse(e.target.value); setErreur(false); }}
              onKeyDown={(e) => e.key === 'Enter' && verifier()} />
          </div>
        )}
        {q.type === 'choix' && (
          <div className="tdn-choix" role="radiogroup">
            {q.options.map((o, i) => (
              <button key={o} type="button" role="radio" aria-checked={choix === i}
                className={choix === i ? 'on' : ''} onClick={() => { setChoix(i); setErreur(false); }}>
                {o}
              </button>
            ))}
          </div>
        )}

        {erreur && <p className="tdn-erreur" role="alert">Ce n&apos;est pas encore ça. Observez bien les lieux.</p>}

        {!dejaFaite && compte.participants.length > 1 && (
          <fieldset className="tdn-fieldset">
            <legend className="tdn-sur">Participants concernés par cette validation</legend>
            {compte.participants.map((p) => {
              const deja = progressions[p.id]?.missionsValidees.includes(mission.numero);
              const coche = selection.includes(p.id);
              return (
                <label key={p.id} className={`tdn-check${deja ? ' tdn-check-off' : ''}`}>
                  <input type="checkbox" checked={coche && !deja} disabled={deja}
                    onChange={(e) => setSelection((s) => e.target.checked ? [...s, p.id] : s.filter((x) => x !== p.id))} />
                  <span>{p.prenom}{deja && <small> · déjà validée</small>}</span>
                </label>
              );
            })}
          </fieldset>
        )}

        {dejaFaite ? (
          <p className="tdn-muted">Mission déjà validée pour {participantActif.prenom}.</p>
        ) : (
          <button className="tdn-btn tdn-btn-or tdn-btn-large"
            disabled={(q.type === 'choix' ? choix === null : !reponse.trim()) || selection.length === 0}
            onClick={verifier}>
            Valider ma réponse
          </button>
        )}
      </section>

      <Indices indices={mission.indices} secours={mission.solutionSecours} />

      <p style={{ textAlign: 'center', marginTop: '1.5rem' }}>
        <Link href="/tresors-de-noel/aventure" className="tdn-lien">Retour à mon aventure</Link>
      </p>
    </>
  );
}
