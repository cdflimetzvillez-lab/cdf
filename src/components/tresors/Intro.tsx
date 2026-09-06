'use client';
import { useEffect, useState } from 'react';
import Neige from './Neige';
import Village from './Village';

const PHRASES = [
  "Cette année, quelque chose s'est passé à Limetz-Villez…",
  'Les cadeaux du Père Noël ont disparu.',
  'Votre mission commence maintenant.',
];
const CADENCE = 2300; // ms par phrase

export default function Intro({ titre, onFin }: { titre: string; onFin: () => void }) {
  const [etape, setEtape] = useState(0);      // 0..2 phrases, 3 titre, 4 sortie
  const [sortie, setSortie] = useState(false);

  useEffect(() => {
    const reduit = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduit) { setEtape(3); const t = setTimeout(terminer, 1800); return () => clearTimeout(t); }
    const timers = [
      setTimeout(() => setEtape(1), CADENCE),
      setTimeout(() => setEtape(2), CADENCE * 2),
      setTimeout(() => setEtape(3), CADENCE * 3),
      setTimeout(terminer, CADENCE * 3 + 2600),
    ];
    return () => timers.forEach(clearTimeout);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function terminer() {
    setSortie(true);
    setTimeout(onFin, 700);
  }

  return (
    <div className={`tdn-intro${sortie ? ' sortie' : ''}`} role="presentation">
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={50} />
      <div className="tdn-halo" aria-hidden="true" />
      <svg className="tdn-traineau" viewBox="0 0 120 40" aria-hidden="true">
        <path d="M2 30 Q10 34 24 30 L28 22 L54 22 L58 30 Q66 34 80 30" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
        <path d="M84 30 l6 -8 l6 8 M96 30 l6 -8 l6 8" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
        <circle cx="106" cy="20" r="2" fill="currentColor" />
      </svg>
      <Village />

      <div className="tdn-intro-texte" aria-live="polite">
        {etape < 3 && <p key={etape} className="tdn-intro-phrase">{PHRASES[etape]}</p>}
        {etape >= 3 && (
          <h1 className="tdn-intro-titre">
            <span className="tdn-scintille">✦</span>
            {titre}
            <span className="tdn-scintille tdn-scintille-2">✦</span>
          </h1>
        )}
      </div>

      <button type="button" className="tdn-passer" onClick={terminer}>Passer l&apos;intro</button>
    </div>
  );
}
