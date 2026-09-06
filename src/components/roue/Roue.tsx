'use client';
import { NB_SEGMENTS, SEGMENTS_GAGNANTS } from '@/lib/roue/types';

const COULEURS = ['#FF3D7F', '#FFF8EC', '#00C2D1', '#FFF8EC', '#5B2A86', '#FFF8EC'];
const R = 150;
const CX = 170, CY = 170;

function arc(i: number) {
  const a0 = (i / NB_SEGMENTS) * 2 * Math.PI - Math.PI / 2;
  const a1 = ((i + 1) / NB_SEGMENTS) * 2 * Math.PI - Math.PI / 2;
  const x0 = CX + R * Math.cos(a0), y0 = CY + R * Math.sin(a0);
  const x1 = CX + R * Math.cos(a1), y1 = CY + R * Math.sin(a1);
  return `M${CX} ${CY} L${x0.toFixed(2)} ${y0.toFixed(2)} A${R} ${R} 0 0 1 ${x1.toFixed(2)} ${y1.toFixed(2)} Z`;
}

function etoile(i: number) {
  const a = ((i + 0.5) / NB_SEGMENTS) * 2 * Math.PI - Math.PI / 2;
  const x = CX + R * 0.66 * Math.cos(a), y = CY + R * 0.66 * Math.sin(a);
  return { x, y, rot: (a * 180) / Math.PI + 90 };
}

/** Roue de fête foraine : bois, ampoules, segments colorés sans texte. `angle` en degrés, animé par le parent. */
export default function Roue({ angle, tourne, onClick, disabled }: { angle: number; tourne: boolean; onClick: () => void; disabled?: boolean }) {
  return (
    <button type="button" className={`roue-btn${tourne ? ' tourne' : ''}`} onClick={onClick} disabled={disabled} aria-label="Lancer la roue">
      <svg viewBox="0 0 340 340" className="roue-svg" aria-hidden="true">
        <defs>
          <radialGradient id="roue-bois" cx="50%" cy="50%" r="50%">
            <stop offset="70%" stopColor="#8a5a2b" /><stop offset="100%" stopColor="#5b3716" />
          </radialGradient>
          <radialGradient id="roue-or" cx="40%" cy="35%" r="70%">
            <stop offset="0%" stopColor="#ffe9a3" /><stop offset="100%" stopColor="#d9a520" />
          </radialGradient>
          <filter id="roue-ombre"><feDropShadow dx="0" dy="6" stdDeviation="4" floodOpacity=".35" /></filter>
        </defs>

        {/* cadre bois + ampoules (fixes) */}
        <circle cx={CX} cy={CY} r="166" fill="url(#roue-bois)" filter="url(#roue-ombre)" />
        <circle cx={CX} cy={CY} r="166" fill="none" stroke="#3b220c" strokeWidth="4" />
        <circle cx={CX} cy={CY} r="152" fill="none" stroke="#3b220c" strokeWidth="3" />
        {Array.from({ length: 24 }).map((_, i) => {
          const a = (i / 24) * 2 * Math.PI;
          return <circle key={i} className="roue-ampoule" style={{ animationDelay: `${(i % 2) * 0.5}s` }} cx={CX + 159 * Math.cos(a)} cy={CY + 159 * Math.sin(a)} r="4.5" fill="#FFD400" />;
        })}

        {/* disque tournant */}
        <g style={{ transform: `rotate(${angle}deg)`, transformOrigin: `${CX}px ${CY}px` }} className="roue-disque">
          {Array.from({ length: NB_SEGMENTS }).map((_, i) => {
            const gagnant = SEGMENTS_GAGNANTS.includes(i);
            return <path key={i} d={arc(i)} fill={gagnant ? 'url(#roue-or)' : COULEURS[i % COULEURS.length]} stroke="#141014" strokeWidth="3" />;
          })}
          {SEGMENTS_GAGNANTS.map((i) => {
            const e = etoile(i);
            return <text key={i} x={e.x} y={e.y} transform={`rotate(${e.rot} ${e.x} ${e.y})`} textAnchor="middle" dominantBaseline="central" fontSize="30" fill="#141014">★</text>;
          })}
          <circle cx={CX} cy={CY} r="32" fill="#141014" />
          <circle cx={CX} cy={CY} r="24" fill="#FFD400" stroke="#141014" strokeWidth="3" />
          <circle cx={CX} cy={CY} r="7" fill="#141014" />
        </g>

        {/* pointeur */}
        <polygon points={`${CX - 16},14 ${CX + 16},14 ${CX},50`} fill="#FF3D7F" stroke="#141014" strokeWidth="3" />
        <circle cx={CX} cy="14" r="8" fill="#FFD400" stroke="#141014" strokeWidth="3" />
      </svg>
    </button>
  );
}
