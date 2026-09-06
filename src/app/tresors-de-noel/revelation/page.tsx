'use client';
import { useEffect, useState } from 'react';
import Neige from '@/components/tresors/Neige';
import { useTresors } from '@/lib/tresors/store';
import { CLES_REVELATION } from '@/lib/tresors/mock';
import type { Lot } from '@/lib/tresors/types';

type Phase = 'saisie' | 'compte' | 'ouverture' | 'revele';

/** Écran grand format pour le Marché de Noël. Lisible à plusieurs mètres. */
export default function PageRevelation() {
  const { progressions, compte } = useTresors();
  const [numero, setNumero] = useState('');
  const [code, setCode] = useState('');
  const [erreur, setErreur] = useState('');
  const [phase, setPhase] = useState<Phase>('saisie');
  const [compteur, setCompteur] = useState(3);
  const [lot, setLot] = useState<Lot | null>(null);

  function chercherLot(num: string, c: string): Lot | null {
    const ref = CLES_REVELATION[num];
    if (ref && ref.code === c) return ref.lot;
    // Clés générées pendant la démo : lot attribué de façon déterministe.
    for (const p of compte.participants) {
      const k = progressions[p.id]?.cle;
      if (k && k.numero === num && k.code === c) {
        const lots = Object.values(CLES_REVELATION).map((r) => r.lot);
        return lots[Number(num) % lots.length];
      }
    }
    return null;
  }

  function ouvrir() {
    const num = numero.trim().padStart(3, '0');
    const c = code.trim().toUpperCase();
    const trouve = chercherLot(num, c);
    if (!trouve) { setErreur('Clé inconnue. Vérifiez le numéro et le code secret.'); return; }
    setErreur('');
    setLot(trouve);
    setPhase('compte');
    setCompteur(3);
  }

  useEffect(() => {
    if (phase !== 'compte') return;
    if (compteur === 0) { setPhase('ouverture'); return; }
    const t = setTimeout(() => setCompteur((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [phase, compteur]);

  useEffect(() => {
    if (phase !== 'ouverture') return;
    const t = setTimeout(() => setPhase('revele'), 1600);
    return () => clearTimeout(t);
  }, [phase]);

  function recommencer() { setPhase('saisie'); setNumero(''); setCode(''); setLot(null); }

  return (
    <main className={`tdn-revelation${lot?.grand && phase === 'revele' ? ' tdn-grand' : ''}`}>
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={60} />

      {phase === 'saisie' && (
        <div className="tdn-rev-inner">
          <div className="tdn-sur tdn-sur-grand">Marché de Noël de Limetz-Villez</div>
          <h1 className="tdn-rev-titre">La Salle aux Trésors</h1>
          <p className="tdn-rev-sous">Entrez votre clé pour découvrir votre cadeau.</p>
          <div className="tdn-rev-form">
            <div className="tdn-champ tdn-champ-grand">
              <label htmlFor="num">Numéro de clé</label>
              <input id="num" inputMode="numeric" placeholder="084" value={numero} onChange={(e) => setNumero(e.target.value)} autoFocus />
            </div>
            <div className="tdn-champ tdn-champ-grand">
              <label htmlFor="code">Code secret</label>
              <input id="code" placeholder="NOEL-XXXX" value={code} onChange={(e) => setCode(e.target.value.toUpperCase())}
                onKeyDown={(e) => e.key === 'Enter' && ouvrir()} autoCapitalize="characters" />
            </div>
            {erreur && <p className="tdn-erreur" role="alert">{erreur}</p>}
            <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={ouvrir} disabled={!numero || !code}>Ouvrir mon trésor</button>
          </div>
          <p className="tdn-muted tdn-mini">Démo : essayez 084 / NOEL-8K4P (grand trésor) ou 012 / NOEL-3F7A.</p>
        </div>
      )}

      {(phase === 'compte' || phase === 'ouverture') && (
        <div className="tdn-rev-inner tdn-rev-scene">
          <div className={`tdn-coffre tdn-coffre-xl${phase === 'ouverture' ? ' ouvert' : ''}`} aria-hidden="true">
            <i className="tdn-coffre-couvercle" /><i className="tdn-coffre-corps" /><i className="tdn-coffre-lueur" />
          </div>
          {phase === 'compte' && <div className="tdn-decompte" key={compteur} aria-live="assertive">{compteur || '✦'}</div>}
        </div>
      )}

      {phase === 'revele' && lot && (
        <div className="tdn-rev-inner tdn-rev-resultat">
          <div className="tdn-particules" aria-hidden="true">
            {Array.from({ length: 24 }).map((_, i) => <i key={i} style={{ left: `${(i * 41) % 100}%`, animationDelay: `${(i % 6) * 0.15}s` }} />)}
          </div>
          {lot.grand && <div className="tdn-grand-tresor">Grand Trésor</div>}
          <h1 className="tdn-rev-titre">Félicitations !</h1>
          <p className="tdn-rev-sous">Vous remportez :</p>
          <div className="tdn-lot">{lot.nom}</div>
          <p className="tdn-rev-partenaire">Offert par notre partenaire <b>{lot.partenaire}</b></p>
          <p className="tdn-muted">Présentez cet écran aux bénévoles pour récupérer votre lot.</p>
          <button className="tdn-btn tdn-btn-ghost" onClick={recommencer}>Clé suivante</button>
        </div>
      )}
    </main>
  );
}
