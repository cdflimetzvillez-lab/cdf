'use client';
import { useActionState, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Roue from './Roue';
import { jouer, reclamer, statutJoueur, type EtatRoue, type ResultatTour } from '@/app/roue-actions';
import { NB_SEGMENTS, type ConfigRoue } from '@/lib/roue/types';
import './roue.css';

const DUREE = 4600; // ms
const CLE_FERME = 'roue-fermee';

type Phase = 'roue' | 'tourne' | 'perdu' | 'gagne' | 'info';

/**
 * Pop-up « Roue de la Rentrée » sur l'accueil.
 * S'ouvre à l'arrivée si le joueur peut encore jouer aujourd'hui. Le tirage est décidé côté serveur.
 */
export default function RoueRentree({ config: c }: { config: ConfigRoue }) {
  const [ouvert, setOuvert] = useState(false);
  const [peutJouer, setPeutJouer] = useState(false);
  const [angle, setAngle] = useState(0);
  const [phase, setPhase] = useState<Phase>('roue');
  const [resultat, setResultat] = useState<ResultatTour | null>(null);
  const toursRef = useRef(0);

  useEffect(() => {
    statutJoueur().then(({ peutJouer }) => {
      setPeutJouer(peutJouer);
      if (peutJouer && sessionStorage.getItem(CLE_FERME) !== '1') setOuvert(true);
    });
  }, []);

  useEffect(() => {
    if (!ouvert) return;
    document.body.style.overflow = 'hidden';
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && phase !== 'tourne' && fermer();
    window.addEventListener('keydown', esc);
    return () => { document.body.style.overflow = ''; window.removeEventListener('keydown', esc); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ouvert, phase]);

  function fermer() {
    if (phase === 'tourne') return;
    sessionStorage.setItem(CLE_FERME, '1');
    setOuvert(false);
    if (phase !== 'roue') setPeutJouer(false);
  }

  async function lancer() {
    if (phase !== 'roue') return;
    setPhase('tourne');
    const r = await jouer();
    setResultat(r);
    if (r.statut !== 'ok') { setPhase('info'); return; }
    const part = 360 / NB_SEGMENTS;
    const cible = 360 - (r.segment * part + part / 2 + (Math.random() - 0.5) * part * 0.6);
    toursRef.current += 1;
    setAngle(toursRef.current * 5 * 360 + cible);
    setTimeout(() => setPhase(r.gagne ? 'gagne' : 'perdu'), DUREE);
  }

  if (!ouvert) {
    // Petit rappel flottant si le joueur a fermé sans jouer.
    return peutJouer ? (
      <button type="button" className="roue-flottant" onClick={() => { sessionStorage.removeItem(CLE_FERME); setOuvert(true); }} aria-label="Ouvrir la Roue de la Rentrée">
        🎡 <span>Jouer</span>
      </button>
    ) : null;
  }

  return (
    <div className="roue-fond" role="dialog" aria-modal="true" aria-labelledby="roue-titre">
      <div className="roue-pop" style={{ ['--roue-duree' as string]: `${DUREE}ms` }}>
        {phase !== 'tourne' && <button className="roue-x" onClick={fermer} aria-label="Fermer">✕</button>}

        {(phase === 'roue' || phase === 'tourne') && (
          <>
            <span className="kicker mono">Jeu gratuit · {c.periode_texte}</span>
            <h2 id="roue-titre">{c.titre}</h2>
            <p className="roue-accroche">{c.accroche}</p>
            <div className="roue-scene">
              <Roue angle={angle} tourne={phase === 'tourne'} onClick={lancer} disabled={phase !== 'roue'} />
            </div>
            <p className="roue-touch">{phase === 'tourne' ? 'Bonne chance…' : '👆 Touchez la roue pour jouer'}</p>
            <p className="roue-mini">
              {c.participations_par_jour > 1 ? `${c.participations_par_jour} tours` : '1 tour'} par jour et par personne · lots à retirer auprès du Comité des Fêtes ·{' '}
              <Link href="/roue-de-la-rentree/reglement">règlement</Link>
            </p>
          </>
        )}

        {phase === 'perdu' && (
          <div className="roue-resultat">
            <div className="roue-badge">Dommage</div>
            <h2 id="roue-titre">Pas cette fois…</h2>
            <p>{c.message_perdu}</p>
            <button className="btn btn-y" onClick={fermer}>D&apos;accord</button>
          </div>
        )}

        {phase === 'gagne' && resultat?.statut === 'ok' && (
          <Gagne resultat={resultat} message={c.message_gagne} onFermer={fermer} />
        )}

        {phase === 'info' && resultat && resultat.statut !== 'ok' && (
          <div className="roue-resultat">
            <div className="roue-badge">{resultat.statut === 'deja_joue' ? 'À demain' : 'Oups'}</div>
            <h2 id="roue-titre">{resultat.statut === 'deja_joue' ? 'Déjà joué' : 'Indisponible'}</h2>
            <p>{resultat.message}</p>
            <button className="btn btn-y" onClick={fermer}>D&apos;accord</button>
          </div>
        )}
      </div>
    </div>
  );
}

function Gagne({ resultat, message, onFermer }: { resultat: Extract<ResultatTour, { statut: 'ok' }>; message: string; onFermer: () => void }) {
  const [etat, action, pending] = useActionState<EtatRoue, FormData>(reclamer, null);
  return (
    <div className="roue-resultat roue-gagne">
      <div className="roue-confettis" aria-hidden="true">{Array.from({ length: 18 }).map((_, i) => <i key={i} style={{ left: `${(i * 53) % 100}%`, animationDelay: `${(i % 6) * .12}s` }} />)}</div>
      <div className="roue-badge roue-badge-or">🎉 Gagné !</div>
      <p className="roue-vous">Vous remportez</p>
      <h2 id="roue-titre">{resultat.lot?.nom}</h2>
      {resultat.lot?.description && <p className="roue-sous">{resultat.lot.description}</p>}
      <div className="roue-code"><span className="mono">Votre code</span><b>{resultat.code}</b></div>
      <p>{message}</p>
      {etat?.annule ? (
        <>
          <div className="msg ko" style={{ fontWeight: 700 }}>⚠️ {etat.annule}</div>
          <button className="btn btn-k" onClick={onFermer}>D&apos;accord</button>
        </>
      ) : etat?.ok ? (
        <>
          <div className="msg ok">{etat.ok}</div>
          <button className="btn btn-k" onClick={onFermer}>Fermer</button>
        </>
      ) : (
        <form action={action} className="roue-form">
          <input type="hidden" name="participation_id" value={resultat.participationId} />
          {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
          <p className="roue-form-aide">Vos coordonnées pour que l&apos;on garde votre lot de côté :</p>
          <div className="row2">
            <div className="field"><label htmlFor="rr-prenom">Prénom</label><input id="rr-prenom" name="prenom" required autoComplete="given-name" /></div>
            <div className="field"><label htmlFor="rr-nom">Nom</label><input id="rr-nom" name="nom" required autoComplete="family-name" /></div>
          </div>
          <div className="field"><label htmlFor="rr-email">E-mail</label><input id="rr-email" name="email" type="email" required autoComplete="email" /></div>
          <div className="field"><label htmlFor="rr-tel">Téléphone</label><input id="rr-tel" name="telephone" type="tel" required autoComplete="tel" /></div>
          <button className="btn btn-y" disabled={pending}>{pending ? 'Envoi…' : 'Réserver mon lot'}</button>
        </form>
      )}
    </div>
  );
}
