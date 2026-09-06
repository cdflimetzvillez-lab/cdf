'use client';
import { useActionState, useEffect, useRef, useState } from 'react';
import Roue from './Roue';
import { jouer, reclamer, type EtatRoue, type ResultatTour } from '@/app/roue-actions';
import { NB_SEGMENTS, type ConfigRoue } from '@/lib/roue/types';
import './roue.css';

const DUREE = 4600; // ms

type Etat = 'repos' | 'tourne' | 'resultat';

/** Bloc « Roue de la Rentrée » intégré à l'accueil. Le résultat vient du serveur, le navigateur anime. */
export default function RoueRentree({ config: c }: { config: ConfigRoue }) {
  const [angle, setAngle] = useState(0);
  const [etat, setEtat] = useState<Etat>('repos');
  const [resultat, setResultat] = useState<ResultatTour | null>(null);
  const [modal, setModal] = useState(false);
  const toursRef = useRef(0);

  async function lancer() {
    if (etat !== 'repos') return;
    setEtat('tourne');
    const r = await jouer();
    if (r.statut !== 'ok') { setResultat(r); setEtat('resultat'); setModal(true); return; }
    // Le segment ciblé doit finir sous le pointeur (en haut). Le segment i couvre [i*30, (i+1)*30] depuis le haut.
    const part = 360 / NB_SEGMENTS;
    const cible = 360 - (r.segment * part + part / 2 + (Math.random() - 0.5) * part * 0.6);
    toursRef.current += 1;
    const nouvelAngle = toursRef.current * 5 * 360 + cible;
    setAngle(nouvelAngle);
    setTimeout(() => { setResultat(r); setEtat('resultat'); setModal(true); }, DUREE);
  }

  function fermer() { setModal(false); setEtat('repos'); }

  useEffect(() => {
    if (!modal) return;
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && fermer();
    window.addEventListener('keydown', esc);
    document.body.style.overflow = 'hidden';
    return () => { window.removeEventListener('keydown', esc); document.body.style.overflow = ''; };
  }, [modal]);

  return (
    <section className="roue" id="roue-rentree" aria-labelledby="roue-titre">
      <div className="wrap roue-grid">
        <div className="roue-texte">
          <span className="kicker mono">Jeu gratuit · {c.periode_texte}</span>
          <h2 id="roue-titre">{c.titre}</h2>
          <p className="roue-accroche">{c.accroche}</p>
          <ul className="roue-infos">
            <li><b>{c.periode_texte}</b></li>
            <li><b>{c.participations_par_jour > 1 ? `${c.participations_par_jour} tours par jour` : '1 tour par jour'}</b> et par personne</li>
            <li><b>De nombreux cadeaux</b> à gagner</li>
          </ul>
          <p className="roue-regles">Cliquez sur la roue, attendez qu&apos;elle s&apos;arrête. Les cases dorées sont gagnantes. Le lot est à retirer auprès du Comité des Fêtes sur présentation du code reçu. Réservé aux habitants et amis de Limetz-Villez, sans obligation d&apos;achat.</p>
        </div>
        <div className="roue-scene" style={{ ['--roue-duree' as string]: `${DUREE}ms` }}>
          <Roue angle={angle} tourne={etat === 'tourne'} onClick={lancer} disabled={etat !== 'repos'} />
          <p className="roue-touch-mobile" aria-hidden="true">👆 Touchez la roue pour jouer</p>
        </div>
      </div>

      {modal && resultat && (
        <div className="roue-modal-fond" onClick={fermer}>
          <div className="roue-modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}>
            <button className="roue-modal-x" onClick={fermer} aria-label="Fermer">✕</button>
            {resultat.statut === 'ok' && resultat.gagne ? (
              <Gagne resultat={resultat} message={c.message_gagne} onFermer={fermer} />
            ) : resultat.statut === 'ok' ? (
              <>
                <div className="roue-modal-badge">Dommage</div>
                <h3>Pas cette fois…</h3>
                <p>{c.message_perdu}</p>
                <button className="btn btn-y" onClick={fermer}>D&apos;accord</button>
              </>
            ) : (
              <>
                <div className="roue-modal-badge">{resultat.statut === 'deja_joue' ? 'À demain' : 'Oups'}</div>
                <h3>{resultat.statut === 'deja_joue' ? 'Déjà joué' : 'Indisponible'}</h3>
                <p>{resultat.message}</p>
                <button className="btn btn-y" onClick={fermer}>D&apos;accord</button>
              </>
            )}
          </div>
        </div>
      )}
    </section>
  );
}

function Gagne({ resultat, message, onFermer }: { resultat: Extract<ResultatTour, { statut: 'ok' }>; message: string; onFermer: () => void }) {
  const [etat, action, pending] = useActionState<EtatRoue, FormData>(reclamer, null);
  return (
    <>
      <div className="roue-modal-badge roue-modal-badge-or">🎉 Gagné !</div>
      <h3>{resultat.lot?.nom}</h3>
      {resultat.lot?.description && <p className="roue-modal-sous">{resultat.lot.description}</p>}
      <div className="roue-code">
        <span className="mono">Votre code</span>
        <b>{resultat.code}</b>
      </div>
      <p>{message}</p>
      {etat?.ok ? (
        <>
          <div className="msg ok">{etat.ok}</div>
          <button className="btn btn-k" onClick={onFermer}>Fermer</button>
        </>
      ) : (
        <form action={action} className="roue-form">
          <input type="hidden" name="participation_id" value={resultat.participationId} />
          {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
          <p className="roue-form-aide">Laissez vos coordonnées pour que l&apos;on garde votre lot de côté.</p>
          <div className="field"><label htmlFor="rr-prenom">Prénom</label><input id="rr-prenom" name="prenom" required autoComplete="given-name" /></div>
          <div className="field"><label htmlFor="rr-email">E-mail</label><input id="rr-email" name="email" type="email" required autoComplete="email" /></div>
          <div className="field"><label htmlFor="rr-tel">Téléphone (optionnel)</label><input id="rr-tel" name="telephone" type="tel" autoComplete="tel" /></div>
          <button className="btn btn-y" disabled={pending}>{pending ? 'Envoi…' : 'Réserver mon lot'}</button>
        </form>
      )}
    </>
  );
}
