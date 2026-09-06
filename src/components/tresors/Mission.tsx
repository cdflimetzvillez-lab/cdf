'use client';
import { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import BlocMission from './BlocMission';
import Indices from './Indices';
import { validerReponse } from '@/app/tresors-actions';
import type { MissionPublique, Progression } from '@/lib/tresors/types';

/** Mission générique : contenu, question, validation multi-participants (côté serveur), indices. */
export default function Mission({ mission: m, progressions, actifId }: { mission: MissionPublique; progressions: Progression[]; actifId: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const actif = progressions.find((p) => p.participant.id === actifId)!;
  const dejaFaite = actif.missionsValidees.includes(m.id);
  const [reponse, setReponse] = useState('');
  const [choix, setChoix] = useState<number | null>(null);
  const [erreur, setErreur] = useState('');
  const [reussi, setReussi] = useState(false);
  const [aTermine, setATermine] = useState(false);
  const [selection, setSelection] = useState<string[]>(() =>
    progressions.filter((p) => p.participant.paye && !p.missionsValidees.includes(m.id)).map((p) => p.participant.id));

  const valeur = m.question_type === 'choix' ? String(choix ?? '') : reponse;
  const pretA = (m.question_type === 'choix' ? choix !== null : !!reponse.trim()) && selection.length > 0;

  function verifier() {
    start(async () => {
      const r = await validerReponse(m.id, valeur, selection);
      if (r.erreur) { setErreur(r.erreur); return; }
      if (!r.ok) { setErreur("Ce n'est pas encore ça. Observez bien les lieux."); return; }
      setErreur('');
      setATermine(r.termines.includes(actifId));
      setReussi(true);
    });
  }

  if (reussi) {
    return (
      <section className="tdn-carte tdn-reussite">
        <div className="tdn-eclat" aria-hidden="true">✦</div>
        <h2 className="tdn-titre-fee">Mission accomplie !</h2>
        <p>{aTermine ? 'Vous venez de résoudre le dernier mystère…' : 'Vous avez débloqué la mission suivante.'}</p>
        <p className="tdn-muted tdn-mini">Validée pour : {progressions.filter((p) => selection.includes(p.participant.id)).map((p) => p.participant.prenom).join(', ')}</p>
        <button className="tdn-btn tdn-btn-or tdn-btn-large" onClick={() => router.push(aTermine ? '/tresors-de-noel/fin' : '/tresors-de-noel/aventure')}>Continuer</button>
      </section>
    );
  }

  return (
    <>
      <section className="tdn-carte">
        {m.lieu && <p className="tdn-lieu">📍 {m.lieu}</p>}
        {m.blocs.map((b, i) => <BlocMission key={i} bloc={b} />)}
      </section>

      <section className="tdn-carte">
        <div className="tdn-sur">Question</div>
        <p className="tdn-question">{m.intitule}</p>

        {m.question_type === 'texte' && (
          <div className="tdn-champ"><label htmlFor="rep" className="tdn-sr">Réponse</label>
            <input id="rep" placeholder={m.placeholder ?? 'Entrer la réponse'} value={reponse} autoCapitalize="none"
              onChange={(e) => { setReponse(e.target.value); setErreur(''); }} onKeyDown={(e) => e.key === 'Enter' && pretA && verifier()} /></div>
        )}
        {m.question_type === 'code' && (
          <div className="tdn-champ"><label htmlFor="rep" className="tdn-sr">Code</label>
            <input id="rep" className="tdn-code-input" inputMode="numeric" maxLength={m.longueur ?? 8} placeholder={'•'.repeat(m.longueur ?? 4)} value={reponse}
              onChange={(e) => { setReponse(e.target.value); setErreur(''); }} onKeyDown={(e) => e.key === 'Enter' && pretA && verifier()} /></div>
        )}
        {m.question_type === 'choix' && (
          <div className="tdn-choix" role="radiogroup">
            {m.options.map((o, i) => (
              <button key={i} type="button" role="radio" aria-checked={choix === i} className={choix === i ? 'on' : ''} onClick={() => { setChoix(i); setErreur(''); }}>{o}</button>
            ))}
          </div>
        )}

        {erreur && <p className="tdn-erreur" role="alert">{erreur}</p>}

        {!dejaFaite && progressions.length > 1 && (
          <fieldset className="tdn-fieldset">
            <legend className="tdn-sur">Participants concernés par cette validation</legend>
            {progressions.map(({ participant: p, missionsValidees }) => {
              const deja = missionsValidees.includes(m.id);
              const bloque = deja || !p.paye;
              return (
                <label key={p.id} className={`tdn-check${bloque ? ' tdn-check-off' : ''}`}>
                  <input type="checkbox" checked={selection.includes(p.id) && !bloque} disabled={bloque}
                    onChange={(e) => setSelection((s) => e.target.checked ? [...s, p.id] : s.filter((x) => x !== p.id))} />
                  <span>{p.prenom}{deja && <small> · déjà validée</small>}{!p.paye && <small> · non réglé</small>}</span>
                </label>
              );
            })}
          </fieldset>
        )}

        {dejaFaite ? (
          <p className="tdn-muted">Mission déjà validée pour {actif.participant.prenom}.</p>
        ) : (
          <button className="tdn-btn tdn-btn-or tdn-btn-large" disabled={!pretA || pending} onClick={verifier}>
            {pending ? 'Vérification…' : 'Valider ma réponse'}
          </button>
        )}
      </section>

      <Indices indices={m.indices} secours={m.solution_secours ?? undefined} />
      <p style={{ textAlign: 'center', marginTop: '1.5rem' }}><Link href="/tresors-de-noel/aventure" className="tdn-lien">Retour à mon aventure</Link></p>
    </>
  );
}
