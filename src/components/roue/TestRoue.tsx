'use client';
import { useRef, useState } from 'react';
import Roue from './Roue';
import { jouerTest, type ResultatTour } from '@/app/roue-actions';
import { NB_SEGMENTS, type ConfigRoue } from '@/lib/roue/types';
import './roue.css';

const DUREE = 4600;

/** Aperçu admin : la vraie roue, le vrai tirage, mais rien n'est enregistré. */
export default function TestRoue({ config: c }: { config: ConfigRoue }) {
  const [angle, setAngle] = useState(0);
  const [tourne, setTourne] = useState(false);
  const [resultat, setResultat] = useState<ResultatTour | null>(null);
  const [historique, setHistorique] = useState<{ gagne: boolean; lot?: string }[]>([]);
  const toursRef = useRef(0);

  async function lancer() {
    if (tourne) return;
    setTourne(true); setResultat(null);
    const r = await jouerTest();
    if (r.statut !== 'ok') { setResultat(r); setTourne(false); return; }
    const part = 360 / NB_SEGMENTS;
    const cible = 360 - (r.segment * part + part / 2 + (Math.random() - 0.5) * part * 0.6);
    toursRef.current += 1;
    setAngle(toursRef.current * 5 * 360 + cible);
    setTimeout(() => {
      setResultat(r); setTourne(false);
      setHistorique((h) => [{ gagne: r.gagne, lot: r.lot?.nom }, ...h].slice(0, 20));
    }, DUREE);
  }

  const gagnes = historique.filter((h) => h.gagne).length;

  return (
    <div className="row2">
      <div className="panel" style={{ background: 'var(--violet)', color: 'var(--creme)', textAlign: 'center' }}>
        <span className="kicker mono">Mode test · rien n&apos;est enregistré</span>
        <h2 style={{ color: 'var(--jaune)', fontSize: '2rem', margin: '.6rem 0' }}>{c.titre}</h2>
        <p style={{ fontWeight: 700, marginBottom: '1rem' }}>{c.accroche}</p>
        <div className="roue-scene" style={{ ['--roue-duree' as string]: `${DUREE}ms` }}>
          <Roue angle={angle} tourne={tourne} onClick={lancer} disabled={tourne} />
        </div>
        <p className="roue-touch">{tourne ? 'Bonne chance…' : '👆 Cliquez sur la roue pour tester'}</p>
      </div>
      <div>
        <div className="panel">
          <h2>Résultat</h2>
          {!resultat && !tourne && <p style={{ color: '#6b6560' }}>Lancez la roue pour voir ce qu&apos;un visiteur obtiendrait. Le tirage utilise le taux de gain ({c.taux_gain} %) et les stocks réels, sans les consommer.</p>}
          {tourne && <p style={{ color: '#6b6560' }}>La roue tourne…</p>}
          {resultat?.statut === 'ok' && resultat.gagne && (
            <>
              <span className="pill done">Gagné</span>
              <p style={{ fontFamily: 'Anton, sans-serif', fontSize: '1.6rem', textTransform: 'uppercase', marginTop: '.6rem' }}>{resultat.lot?.nom}</p>
              {resultat.lot?.description && <p style={{ color: '#6b6560' }}>{resultat.lot.description}</p>}
              <p style={{ marginTop: '.6rem', fontSize: '.9rem' }}>{c.message_gagne}</p>
            </>
          )}
          {resultat?.statut === 'ok' && !resultat.gagne && (
            <>
              <span className="pill off">Perdu</span>
              <p style={{ marginTop: '.6rem' }}>{c.message_perdu}</p>
            </>
          )}
          {resultat && resultat.statut !== 'ok' && <div className="msg ko">{resultat.message}</div>}
        </div>
        {historique.length > 0 && (
          <div className="panel">
            <h2>Derniers essais</h2>
            <p style={{ color: '#6b6560', marginBottom: '.6rem' }}>{gagnes} gagnant{gagnes > 1 ? 's' : ''} sur {historique.length}</p>
            <ul style={{ listStyle: 'none', display: 'flex', flexWrap: 'wrap', gap: '.4rem' }}>
              {historique.map((h, i) => <li key={i}><span className={`pill ${h.gagne ? 'done' : 'off'}`}>{h.gagne ? h.lot : 'perdu'}</span></li>)}
            </ul>
          </div>
        )}
      </div>
    </div>
  );
}
