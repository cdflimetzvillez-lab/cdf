import Link from 'next/link';
import type { CSSProperties, ReactNode } from 'react';
import Traineau from './Traineau';

/**
 * Carte du parcours de « Mon aventure » : un chemin qui serpente dans le village de nuit,
 * une étape par mission, le lutin posé à côté de l'étape en cours et le coffre au bout du chemin.
 *
 * Composant serveur, SVG + CSS uniquement (styles et animations : bloc .tdn-map de tresors.css).
 * Le dessin est fait dans un repère fixe de 360 × 800 ; il s'adapte à la largeur de l'écran.
 * Le nombre d'étapes suit le nombre de missions publiées : elles sont réparties à distance égale sur le chemin.
 */

export type EtapeCarte = { numero: number; titre: string; etat: 'faite' | 'courante' | 'verrou' };

type Props = {
  etapes: EtapeCarte[];
  /** Nombre de missions validées : allume progressivement le village. */
  faites: number;
  /** Toutes les missions sont validées : le coffre est ouvert. */
  termine: boolean;
  /** Participation réglée et jeu ouvert : l'étape en cours est cliquable. */
  jouable: boolean;
  /** Numéro de la mission qui vient d'être validée : joue l'animation « mission accomplie ». */
  bravo?: number | null;
};

type Pt = { x: number; y: number };
type Mode = 'on' | 'off' | 'anim';

const LARGEUR = 360;
const HAUTEUR = 800;
const Y_DEPART = 604;
const Y_ARRIVEE = 263;
const CENTRE = 180;
const AMPLITUDE = 100;
const COFFRE: Pt = { x: 180, y: 218 };

const MUR = '#1a2a5c';
const MUR_CLAIR = '#1f2f66';
const TOIT = '#0d183a';
const NEIGE = '#eef3ff';
const PORTE = '#7a2434';
const NOIR = '#0a1432';
const LUEUR = 'url(#tdnm-lueur)';
const ECLAT = 'M0 -5Q.8 -.8 5 0Q.8 .8 0 5Q-.8 .8 -5 0Q-.8 -.8 0 -5Z';

const r = (v: number) => Math.round(v * 10) / 10;
const pc = (v: number, total: number) => `${r((v / total) * 100)}%`;

/** Chemin sinueux + position des n étapes, à distance égale le long du chemin. */
function tracer(n: number): { chemin: string; noeuds: Pt[] } {
  const N = 600;
  const pts: Pt[] = [];
  const cumul: number[] = [0];
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    pts.push({ x: CENTRE + AMPLITUDE * Math.sin(3 * Math.PI * t), y: Y_DEPART - (Y_DEPART - Y_ARRIVEE) * t });
    if (i > 0) cumul.push(cumul[i - 1] + Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
  }
  const noeuds: Pt[] = [];
  let j = 0;
  for (let k = 0; k < n; k++) {
    const cible = n > 1 ? (cumul[N] * k) / (n - 1) : 0;
    while (j < N && cumul[j] < cible) j++;
    noeuds.push(pts[j]);
  }
  const chemin = 'M' + pts.filter((_, i) => i % 6 === 0).map((p) => `${r(p.x)} ${r(p.y)}`).join(' L');
  return { chemin, noeuds };
}

/** Le lutin se tient à côté de l'étape, du côté intérieur du virage. */
const aCote = (p: Pt): Pt => ({ x: p.x <= CENTRE + 0.5 ? p.x + 30 : p.x - 30, y: p.y + 10 });

function etoile(cx: number, cy: number, grand: number, petit: number) {
  return Array.from({ length: 10 }, (_, i) => {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rayon = i % 2 === 0 ? grand : petit;
    return `${r(cx + rayon * Math.cos(a))},${r(cy + rayon * Math.sin(a))}`;
  }).join(' ');
}

/* ------------------------------------------------------------------ décor */

/** Tout ce qui s'allume : fenêtres, fumée, guirlandes. Absent tant que la mission associée n'est pas validée. */
function Lum({ mode, children }: { mode: Mode; children: ReactNode }) {
  if (mode === 'off') return null;
  return <g className={mode === 'anim' ? 'm-b-allume' : undefined}>{children}</g>;
}

function Fenetre({ x, y, w, h, mode, d, mur }: { x: number; y: number; w: number; h: number; mode: Mode; d: number; mur: string }) {
  return (
    <>
      <rect x={r(x)} y={r(y)} width={w} height={h} fill={NOIR} />
      <Lum mode={mode}><rect className={`m-fen m-d${d}`} x={r(x)} y={r(y)} width={w} height={h} fill="#f8d27e" /></Lum>
      <path d={`M${r(x + w / 2)} ${r(y)}V${r(y + h)}M${r(x)} ${r(y + h / 2)}H${r(x + w)}`} stroke={mur} strokeWidth={1} fill="none" />
    </>
  );
}

function Fumee({ x, y }: { x: number; y: number }) {
  return <>{[1, 2, 3].map((d) => <circle key={d} className={`m-fumee m-d${d}`} cx={r(x)} cy={r(y)} r={2.8} fill="#dfe8ff" />)}</>;
}

function Maison({ x, y, w, h, rh, mode, d, mur = MUR }: { x: number; y: number; w: number; h: number; rh: number; mode: Mode; d: number; mur?: string }) {
  const g = x - w / 2;
  const dr = x + w / 2;
  const t = y - h;
  const dx = w * 0.24;
  const cx = x + dx;
  const cy = t - rh * (1 - dx / (w / 2 + 5)) - 8;
  const wy = t + Math.max(5, (h - 14) / 2 - 1);
  return (
    <g>
      <Lum mode={mode}><ellipse cx={x} cy={y + 3} rx={r(w * 0.8)} ry={9} fill={LUEUR} /></Lum>
      <ellipse cx={x} cy={y} rx={w / 2 + 7} ry={3.5} fill={NEIGE} opacity={0.28} />
      <rect x={r(cx - 3.5)} y={r(cy)} width={7} height={12} fill="#3b5092" />
      <rect x={r(cx - 5)} y={r(cy - 2)} width={10} height={3} rx={1.5} fill={NEIGE} />
      <rect x={g} y={t} width={w} height={h} fill={mur} />
      <rect x={dr - 6} y={t} width={6} height={h} fill="#000" opacity={0.16} />
      <polygon points={`${g - 5},${t} ${x},${t - rh} ${dr + 5},${t}`} fill={TOIT} />
      <path d={`M${g - 6} ${t + 0.5}L${x} ${t - rh - 1.5}L${dr + 6} ${t + 0.5}L${dr - 1} ${t - 1.5}L${x} ${t - rh + 6}L${g + 1} ${t - 1.5}Z`} fill={NEIGE} />
      <rect x={x - 4.5} y={y - 14} width={9} height={14} rx={1.2} fill={PORTE} />
      <circle cx={x + 2.6} cy={y - 7} r={0.9} fill="#e5c07b" />
      <Fenetre x={g + 5} y={wy} w={9} h={10} mode={mode} d={d} mur={mur} />
      <Fenetre x={dr - 14} y={wy} w={9} h={10} mode={mode} d={(d % 3) + 1} mur={mur} />
      <Lum mode={mode}><Fumee x={cx} y={cy - 4} /></Lum>
    </g>
  );
}

/** x = bord gauche de la nef, y = sol. Le vitrail s'illumine avec la mission associée. */
function Eglise({ x, y, mode }: { x: number; y: number; mode: Mode }) {
  const tx = x + 38;
  const bx = tx + 8;
  const by = y - 58;
  const baie = `M${bx} ${by + 12}V${by + 4}A4 4 0 0 1 ${bx + 8} ${by + 4}V${by + 12}Z`;
  const vx = x + 13;
  const vy = y - 26;
  const vitrail = `M${vx} ${vy + 20}V${vy + 7}A7 7 0 0 1 ${vx + 14} ${vy + 7}V${vy + 20}Z`;
  return (
    <g>
      <Lum mode={mode}><ellipse cx={x + 32} cy={y + 3} rx={40} ry={10} fill={LUEUR} /></Lum>
      <ellipse cx={x + 32} cy={y} rx={40} ry={3.5} fill={NEIGE} opacity={0.28} />
      <rect x={x} y={y - 32} width={40} height={32} fill="#1c2d61" />
      <polygon points={`${x - 4},${y - 32} ${x + 20},${y - 52} ${x + 44},${y - 32}`} fill={TOIT} />
      <path d={`M${x - 5} ${y - 31.5}L${x + 20} ${y - 53.5}L${x + 45} ${y - 31.5}L${x + 39} ${y - 33.5}L${x + 20} ${y - 46}L${x + 1} ${y - 33.5}Z`} fill={NEIGE} />
      <rect x={tx} y={y - 70} width={24} height={70} fill="#203268" />
      <rect x={tx + 18} y={y - 70} width={6} height={70} fill="#000" opacity={0.16} />
      <polygon points={`${tx - 3},${y - 70} ${tx + 12},${y - 104} ${tx + 27},${y - 70}`} fill={TOIT} />
      <path d={`M${tx - 4} ${y - 69.5}L${tx + 12} ${y - 106}L${tx + 15} ${y - 99}L${tx + 2} ${y - 71.5}Z`} fill={NEIGE} />
      <path d={`M${tx + 12} ${y - 105}V${y - 116}M${tx + 8.5} ${y - 112}H${tx + 15.5}`} stroke="#e5c07b" strokeWidth={1.6} strokeLinecap="round" />
      <path d={baie} fill={NOIR} />
      <Lum mode={mode}><path className="m-fen m-d2" d={baie} fill="#f8d27e" /></Lum>
      <rect x={tx + 7} y={y - 14} width={10} height={14} rx={5} fill={PORTE} />
      <rect x={tx + 7} y={y - 8} width={10} height={8} fill={PORTE} />
      <path d={vitrail} fill={NOIR} />
      <Lum mode={mode}>
        <g className="m-fen m-d1">
          <circle className="m-halo" cx={vx + 7} cy={vy + 10} r={22} fill={LUEUR} />
          <path d={vitrail} fill="#f6cf6f" />
          <rect x={vx} y={vy + 7} width={7} height={6.5} fill="#d2506a" />
          <rect x={vx + 7} y={vy + 7} width={7} height={6.5} fill="#5f93ea" />
          <rect x={vx} y={vy + 13.5} width={7} height={6.5} fill="#49b58a" />
          <rect x={vx + 7} y={vy + 13.5} width={7} height={6.5} fill="#d2506a" />
        </g>
      </Lum>
      <path d={`M${vx + 7} ${vy + 1}V${vy + 20}M${vx} ${vy + 7}H${vx + 14}M${vx} ${vy + 13.5}H${vx + 14}`} stroke={TOIT} strokeWidth={1} fill="none" />
    </g>
  );
}

function Mairie({ x, y, mode }: { x: number; y: number; mode: Mode }) {
  const g = x - 36;
  const t = y - 34;
  const mur = '#1c2d61';
  return (
    <g>
      <Lum mode={mode}><ellipse cx={x} cy={y + 3} rx={52} ry={10} fill={LUEUR} /></Lum>
      <ellipse cx={x} cy={y} rx={44} ry={3.5} fill={NEIGE} opacity={0.28} />
      <path d={`M${x} ${t - 14}V${t - 36}`} stroke="#9aa7cc" strokeWidth={1.2} />
      <rect x={x + 0.6} y={t - 36} width={4} height={8} fill="#3b63d1" />
      <rect x={x + 4.6} y={t - 36} width={4} height={8} fill="#f4f1e6" />
      <rect x={x + 8.6} y={t - 36} width={4} height={8} fill="#d2455a" />
      <rect x={g} y={t} width={72} height={34} fill={mur} />
      <rect x={g + 66} y={t} width={6} height={34} fill="#000" opacity={0.16} />
      <polygon points={`${g - 4},${t} ${g + 8},${t - 14} ${g + 64},${t - 14} ${g + 76},${t}`} fill={TOIT} />
      <path d={`M${g - 5} ${t + 0.5}L${g + 7.5} ${t - 15.5}H${g + 64.5}L${g + 77} ${t + 0.5}L${g + 71} ${t - 1.5}L${g + 62} ${t - 10.5}H${g + 10}L${g + 1} ${t - 1.5}Z`} fill={NEIGE} />
      <polygon points={`${x - 13},${t} ${x},${t - 15} ${x + 13},${t}`} fill="#24376f" />
      <circle cx={x} cy={t - 5.5} r={4.6} fill={NOIR} />
      <Lum mode={mode}><circle className="m-fen m-d3" cx={x} cy={t - 5.5} r={4.6} fill="#f8e7b4" /></Lum>
      <path d={`M${x} ${t - 8.5}V${t - 5.5}H${x + 2.4}`} stroke={TOIT} strokeWidth={1} fill="none" />
      <rect x={x - 5.5} y={y - 16} width={11} height={16} rx={1.2} fill={PORTE} />
      <rect x={x - 9.5} y={y - 2} width={19} height={2.5} fill="#33498a" />
      {[6, 19, 45, 58].map((dx, i) => <Fenetre key={dx} x={g + dx} y={t + 9} w={8} h={11} mode={mode} d={(i % 3) + 1} mur={mur} />)}
    </g>
  );
}

/** Chalet du Marché de Noël. */
function Chalet({ x, y, mode, d }: { x: number; y: number; mode: Mode; d: number }) {
  const lampions = ['#ffd98a', '#ff7f8f', '#ffd98a', '#9cc2ff', '#ffd98a'];
  return (
    <g>
      <Lum mode={mode}><ellipse cx={x} cy={y + 3} rx={30} ry={8} fill={LUEUR} /></Lum>
      <ellipse cx={x} cy={y} rx={24} ry={3} fill={NEIGE} opacity={0.28} />
      <rect x={x - 17} y={y - 26} width={34} height={26} fill={NOIR} />
      <Lum mode={mode}><rect className={`m-fen m-d${d}`} x={x - 17} y={y - 26} width={34} height={14} fill="#f8d27e" /></Lum>
      <rect x={x - 17} y={y - 13} width={34} height={13} fill="#4a2c17" />
      <path d={`M${x - 8} ${y - 13}V${y}M${x} ${y - 13}V${y}M${x + 8} ${y - 13}V${y}`} stroke="#2c190c" strokeWidth={1} fill="none" />
      <rect x={x - 18.5} y={y - 26} width={3} height={26} fill="#2c190c" />
      <rect x={x + 15.5} y={y - 26} width={3} height={26} fill="#2c190c" />
      <polygon points={`${x - 19},${y - 34} ${x + 19},${y - 34} ${x + 23},${y - 24} ${x - 23},${y - 24}`} fill="#f3ead8" />
      {[0, 1, 2, 3].map((i) => {
        const a = x - 19 + i * 10.2;
        const b = a - 4 + i * 2.1;
        return <polygon key={i} points={`${r(a)},${y - 34} ${r(a + 5)},${y - 34} ${r(b + 5.2)},${y - 24} ${r(b)},${y - 24}`} fill="#a8344a" />;
      })}
      <rect x={x - 21} y={y - 37} width={42} height={4.5} rx={2.2} fill={NEIGE} />
      <Lum mode={mode}>
        {lampions.map((c, i) => <circle key={i} className={`m-guir m-d${(i % 3) + 1}`} cx={r(x - 15 + i * 7.5)} cy={r(y - 21.5 + (i % 2 ? 1.6 : 0))} r={1.5} fill={c} />)}
      </Lum>
    </g>
  );
}

function Sapin({ x, y, s = 1 }: { x: number; y: number; s?: number }) {
  const a = (v: number) => r(v * s);
  return (
    <g transform={`translate(${x} ${y})`}>
      <ellipse cx={0} cy={0} rx={a(13)} ry={a(2.6)} fill={NEIGE} opacity={0.25} />
      <rect x={a(-2)} y={a(-6)} width={a(4)} height={a(6)} fill="#101a35" />
      <polygon points={`0,${a(-26)} ${a(-12)},${a(-4)} ${a(12)},${a(-4)}`} fill="#12392f" />
      <polygon points={`0,${a(-36)} ${a(-9)},${a(-17)} ${a(9)},${a(-17)}`} fill="#174838" />
      <path d={`M0 ${a(-37)}L${a(-5.5)} ${a(-25)}Q0 ${a(-29)} ${a(5.5)} ${a(-25)}Z`} fill={NEIGE} />
      <path d={`M${a(-12)} ${a(-4)}Q${a(-9)} ${a(-8)} ${a(-5)} ${a(-10)}L${a(-7.5)} ${a(-13)}Z`} fill={NEIGE} opacity={0.9} />
    </g>
  );
}

/** Grand sapin du Marché de Noël : ses guirlandes s'allument en dernier. */
function GrandSapin({ x, y, mode }: { x: number; y: number; mode: Mode }) {
  const etages: [number, number, number, string][] = [[64, -8, -36, '#123d31'], [52, -28, -54, '#16493a'], [40, -46, -70, '#1a5644'], [26, -62, -84, '#1f634e']];
  const boules: [number, number, string][] = [
    [-18, -14, '#ffd98a'], [2, -17, '#ff7f8f'], [19, -13, '#9cc2ff'], [-11, -27, '#ff7f8f'], [10, -30, '#ffd98a'], [-15, -38, '#9cc2ff'],
    [1, -41, '#ffd98a'], [13, -50, '#ff7f8f'], [-8, -53, '#ffd98a'], [4, -64, '#9cc2ff'], [-4, -73, '#ff7f8f'],
  ];
  const cime = etoile(x, y - 90, 7, 3);
  return (
    <g>
      <Lum mode={mode}><ellipse cx={x} cy={y + 2} rx={44} ry={10} fill={LUEUR} /></Lum>
      <ellipse cx={x} cy={y} rx={30} ry={4} fill={NEIGE} opacity={0.28} />
      <rect x={x - 4} y={y - 10} width={8} height={10} fill="#2c190c" />
      {etages.map(([w, bas, haut, couleur]) => (
        <g key={w}>
          <polygon points={`${x},${y + haut} ${x - w / 2},${y + bas} ${x + w / 2},${y + bas}`} fill={couleur} />
          <path d={`M${x - w / 2} ${y + bas}q4 -5 9 -6l-4 6z`} fill={NEIGE} opacity={0.92} />
          <path d={`M${x + w / 2} ${y + bas}q-4 -5 -9 -6l4 6z`} fill={NEIGE} opacity={0.92} />
        </g>
      ))}
      <path d={`M${x} ${y - 85}l-6 13q6 -4 12 0z`} fill={NEIGE} />
      <Lum mode={mode}>
        {boules.map(([dx, dy, c], i) => <circle key={i} className={`m-guir m-d${(i % 3) + 1}`} cx={x + dx} cy={y + dy} r={2.1} fill={c} />)}
      </Lum>
      <polygon points={cime} fill="#55607f" />
      <Lum mode={mode}>
        <circle className="m-halo" cx={x} cy={y - 90} r={16} fill={LUEUR} />
        <polygon className="m-fen m-d2" points={cime} fill="#ffe29a" />
      </Lum>
    </g>
  );
}

function Bonhomme({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <ellipse cx={x} cy={y + 1} rx={12} ry={3} fill={NOIR} opacity={0.25} />
      <circle cx={x} cy={y - 8} r={8.5} fill="#f1f5ff" />
      <circle cx={x} cy={y - 20} r={6.2} fill="#f1f5ff" />
      <circle cx={x} cy={y - 29.5} r={4.6} fill="#f1f5ff" />
      <path d={`M${x - 4.5} ${y - 25}h9`} stroke="#a8344a" strokeWidth={2.4} strokeLinecap="round" />
      <rect x={x - 4.5} y={y - 35} width={9} height={1.8} fill={TOIT} />
      <rect x={x - 3} y={y - 40} width={6} height={5.5} fill={TOIT} />
      <circle cx={x - 1.6} cy={y - 30.5} r={0.8} fill={TOIT} />
      <circle cx={x + 1.8} cy={y - 30.5} r={0.8} fill={TOIT} />
      <path d={`M${x + 0.4} ${y - 29}l5 1.2l-5 1z`} fill="#f08a3c" />
    </g>
  );
}

/** Guirlandes tendues entre les toits : visibles quand tout le village est illuminé. */
function Guirlandes() {
  const couleurs = ['#ffd98a', '#ff7f8f', '#9cc2ff', '#8fe0b4'];
  const fils: [Pt, Pt, Pt, number][] = [
    [{ x: 46, y: 311 }, { x: 80, y: 318 }, { x: 112, y: 286 }, 6],
    [{ x: 58, y: 565 }, { x: 92, y: 566 }, { x: 118, y: 521 }, 6],
    [{ x: 0, y: 214 }, { x: 12, y: 226 }, { x: 30, y: 216 }, 3],
    [{ x: 344, y: 232 }, { x: 354, y: 240 }, { x: 360, y: 232 }, 2],
  ];
  return (
    <>
      {fils.map(([a, c, b, nb], k) => (
        <g key={k}>
          <path d={`M${a.x} ${a.y}Q${c.x} ${c.y} ${b.x} ${b.y}`} fill="none" stroke={NOIR} strokeWidth={1} />
          {Array.from({ length: nb }, (_, i) => {
            const t = (i + 0.5) / nb;
            const x = (1 - t) ** 2 * a.x + 2 * t * (1 - t) * c.x + t * t * b.x;
            const y = (1 - t) ** 2 * a.y + 2 * t * (1 - t) * c.y + t * t * b.y;
            return <circle key={i} className={`m-guir m-d${(i % 3) + 1}`} cx={r(x)} cy={r(y + 2)} r={2.1} fill={couleurs[i % 4]} />;
          })}
        </g>
      ))}
    </>
  );
}

function Coffre({ ouvert }: { ouvert: boolean }) {
  const { x, y } = COFFRE;
  const dome = (dy: number) => `M${x - 19} ${y - 19 + dy}Q${x - 19} ${y - 34 + dy} ${x} ${y - 34 + dy}Q${x + 19} ${y - 34 + dy} ${x + 19} ${y - 19 + dy}Z`;
  const bandes = (dy: number) => [-1, 1].map((s) => (
    <path key={s} d={`M${x + s * 10.3} ${y - 19 + dy}Q${x + s * 10.3} ${y - 31 + dy} ${x + s * 9} ${y - 32.6 + dy}`} fill="none" stroke="#d9ad55" strokeWidth={3.4} />
  ));
  const caisse = (
    <>
      <rect x={x - 18} y={y - 19} width={36} height={19} rx={2} fill="#6a3b1f" />
      <rect x={x - 18} y={y - 3} width={36} height={3} fill="#3f2110" opacity={0.6} />
      <rect x={x - 12} y={y - 19} width={3.4} height={19} fill="#d9ad55" />
      <rect x={x + 8.6} y={y - 19} width={3.4} height={19} fill="#d9ad55" />
    </>
  );
  const scintillements: [number, number][] = [[-30, -40], [28, -50], [-14, -70], [16, -78], [-40, -18], [40, -22]];
  return (
    <g>
      <ellipse cx={x} cy={y + 3} rx={48} ry={11} fill={NEIGE} opacity={0.22} />
      <circle className="m-halo" cx={x} cy={y - 14} r={ouvert ? 66 : 40} fill={LUEUR} />
      {ouvert ? (
        <>
          <path d={dome(-13)} fill="#7d4726" />
          {bandes(-13)}
          <path d={`M${x - 15.5} ${y - 32}Q${x - 15.5} ${y - 43.5} ${x} ${y - 43.5}Q${x + 15.5} ${y - 43.5} ${x + 15.5} ${y - 32}Z`} fill="#3a1f0e" />
          <g className="m-rayons">
            {Array.from({ length: 9 }, (_, i) => (
              <polygon key={i} transform={`rotate(${(i - 4) * 20} ${x} ${y - 20})`} points={`${x - 3.2},${y - 20} ${x},${y - 98} ${x + 3.2},${y - 20}`} fill="url(#tdnm-rayon)" />
            ))}
          </g>
          {caisse}
          <ellipse cx={x} cy={y - 20} rx={17} ry={5} fill="#fff3c4" />
          <ellipse cx={x} cy={y - 20.5} rx={11} ry={3} fill="#fff" />
          {scintillements.map(([dx, dy], i) => (
            <g key={i} transform={`translate(${x + dx} ${y + dy})`}><path className={`m-scint m-d${(i % 3) + 1}`} d={ECLAT} fill="#ffe9ad" /></g>
          ))}
          <g transform={`translate(${x - 1} ${y - 58})`}>
            <g className="m-cle">
              <circle cx={-7} cy={0} r={5} fill="none" stroke="#ffe29a" strokeWidth={2.6} />
              <path d="M-2 0H12M8 0v5M4 0v4" stroke="#ffe29a" strokeWidth={2.6} strokeLinecap="round" fill="none" />
            </g>
          </g>
        </>
      ) : (
        <>
          {caisse}
          <path d={dome(0)} fill="#7d4726" />
          {bandes(0)}
          <path d={`M${x - 15} ${y - 30}Q${x - 10} ${y - 35.5} ${x} ${y - 35.5}Q${x + 10} ${y - 35.5} ${x + 15} ${y - 30}`} fill="none" stroke={NEIGE} strokeWidth={2.2} strokeLinecap="round" />
          <rect x={x - 3.5} y={y - 23} width={7} height={8} rx={1.2} fill="#e5c07b" />
          <circle cx={x} cy={y - 19.6} r={1.2} fill="#3f2110" />
        </>
      )}
    </g>
  );
}

/** Le lutin de l'histoire : bonnet bordeaux, tunique verte, lanterne à la main. Origine = ses pieds. */
function Lutin({ p, className, style }: { p: Pt; className?: string; style?: CSSProperties }) {
  return (
    <g transform={`translate(${r(p.x)} ${r(p.y)})`}>
      <g className={className} style={style}>
        <ellipse cx={0} cy={1.5} rx={10} ry={3} fill="#040a1c" opacity={0.38} />
        <g className="m-saut">
          <g transform="scale(.84)">
            <circle className="m-halo m-lanterne" cx={13} cy={-27} r={13} fill={LUEUR} />
            <ellipse cx={-4.6} cy={-0.8} rx={4.6} ry={2.3} fill="#3a2416" />
            <ellipse cx={4.6} cy={-0.8} rx={4.6} ry={2.3} fill="#3a2416" />
            <rect x={-6} y={-10} width={4.4} height={9} fill="#b5384e" />
            <rect x={1.6} y={-10} width={4.4} height={9} fill="#b5384e" />
            <path d="M-9 -9L-6.5 -23Q0 -26 6.5 -23L9 -9Q0 -5.5 -9 -9Z" fill="#35a876" />
            <rect x={-8} y={-15} width={16} height={3.2} fill="#20150f" />
            <rect x={-2.2} y={-15.6} width={4.4} height={4.4} rx={0.8} fill="#e5c07b" />
            <path d="M-6 -21L-11.5 -14.5" stroke="#35a876" strokeWidth={3.6} strokeLinecap="round" />
            <circle cx={-12} cy={-13.8} r={2.1} fill="#f2cfa8" />
            <path d="M6 -21L12 -25.5" stroke="#35a876" strokeWidth={3.6} strokeLinecap="round" />
            <circle cx={12.6} cy={-26} r={2.1} fill="#f2cfa8" />
            <path d="M13 -31.5V-29" stroke="#e5c07b" strokeWidth={1} />
            <rect x={10.4} y={-29} width={5.2} height={7} rx={1.2} fill="#ffe29a" stroke="#8a5a1c" strokeWidth={0.9} />
            <path d="M-6.2 -29.5L-12.5 -33L-6.4 -25.5Z" fill="#f2cfa8" />
            <path d="M6.2 -29.5L12.5 -33L6.4 -25.5Z" fill="#f2cfa8" />
            <circle cx={0} cy={-29} r={7.2} fill="#f2cfa8" />
            <circle cx={-2.6} cy={-29.4} r={1} fill="#2a1a12" />
            <circle cx={2.6} cy={-29.4} r={1} fill="#2a1a12" />
            <circle cx={-4.6} cy={-26.8} r={1.5} fill="#e88a8a" opacity={0.6} />
            <circle cx={4.6} cy={-26.8} r={1.5} fill="#e88a8a" opacity={0.6} />
            <path d="M-2.4 -26Q0 -23.8 2.4 -26" stroke="#8a3b2a" strokeWidth={0.9} fill="none" strokeLinecap="round" />
            <path d="M-7.6 -32.5Q-4 -50 8 -47Q3.5 -41 7.6 -32.5Z" fill="#b5384e" />
            <rect x={-8.4} y={-35} width={16.8} height={4} rx={2} fill="#fbf7ef" />
            <circle cx={8.6} cy={-47.2} r={2.8} fill="#fbf7ef" />
          </g>
        </g>
      </g>
    </g>
  );
}

/** Une étape du chemin : dorée (validée), claire et pulsante (en cours), sombre sous la neige (à venir). */
function Etape({ p, numero, etat, className }: { p: Pt; numero: number; etat: EtapeCarte['etat']; className?: string }) {
  const x = r(p.x);
  const y = r(p.y);
  if (etat === 'faite') {
    return (
      <g className={className}>
        <circle cx={x} cy={y + 3.5} r={17} fill="#8a631b" />
        <circle cx={x} cy={y} r={17} fill="url(#tdnm-or)" stroke="#fff1c9" strokeWidth={1.3} />
        <polygon points={etoile(x, y + 0.4, 8.6, 3.6)} fill="#0b1736" />
      </g>
    );
  }
  if (etat === 'courante') {
    return (
      <g className={className}>
        <circle className="m-onde" cx={x} cy={y} r={17} fill="none" stroke="#e5c07b" strokeWidth={2} />
        <circle className="m-onde m-d2" cx={x} cy={y} r={17} fill="none" stroke="#e5c07b" strokeWidth={2} />
        <circle cx={x} cy={y + 3.5} r={17} fill="#a89f88" />
        <circle cx={x} cy={y} r={17} fill="#fbf7ef" stroke="#e5c07b" strokeWidth={2.4} />
        <text className="m-num" x={x} y={y} dy=".36em" textAnchor="middle" fill="#081430">{numero}</text>
      </g>
    );
  }
  return (
    <g className={className}>
      <circle cx={x} cy={y + 3.5} r={17} fill="#0a1533" />
      <circle cx={x} cy={y} r={17} fill="#162757" stroke="#5a6da3" strokeWidth={1.2} />
      <text className="m-num" x={x} y={y} dy=".36em" textAnchor="middle" fill="#8fa0cc">{numero}</text>
      <path d={`M${r(x - 13)} ${r(y - 11)}Q${r(x - 9.5)} ${r(y - 20.5)} ${x} ${r(y - 20.5)}Q${r(x + 9.5)} ${r(y - 20.5)} ${r(x + 13)} ${r(y - 11)}Q${r(x + 7)} ${r(y - 16)} ${x} ${r(y - 15.4)}Q${r(x - 7)} ${r(y - 16)} ${r(x - 13)} ${r(y - 11)}Z`} fill={NEIGE} />
    </g>
  );
}

/* ------------------------------------------------------------------ ciel et horizon (dessin fixe) */

const ETOILES: [number, number, number][] = [
  [88.8, 95.1, 0.9], [324.7, 83.8, 1.3], [28.8, 10.1, 1.1], [96.3, 45.5, 1.1], [194.3, 95.9, 1.1], [228.4, 32.1, 0.7], [308.1, 91.7, 0.6], [239.7, 18.2, 1.3],
  [20.9, 132.8, 0.9], [170.5, 123, 1.1], [254.5, 155.4, 1.1], [259.4, 100.3, 0.7], [311.8, 23.6, 0.7], [178.2, 49.3, 1.1], [277.1, 144.8, 1.1], [182.5, 69.7, 0.9],
  [191.9, 73.2, 0.7], [320.7, 117.1, 0.6], [304, 166.6, 0.7], [249.1, 60.2, 1.3], [320.8, 99.1, 0.7], [226.3, 166.1, 0.9], [105.2, 18.2, 1.1], [36.8, 136.1, 1.1],
  [318.2, 11.2, 1.1], [273.5, 147.6, 0.6], [216.5, 129.9, 1.1], [256, 61, 0.9], [181.9, 167.8, 0.9], [8.5, 25.3, 1.3], [16.9, 39.6, 1.1], [107.5, 50.1, 0.6],
  [347, 62.4, 0.9], [339.6, 151.5, 1.1],
];

const FORET = 'M-4 184.4L1.4 166.9L6.8 184.4ZM4.9 183.6L10 160.5L15.2 183.6ZM13.3 182.8L18.8 164.7L24.3 182.8ZM22.3 182.1L27.6 167.9L32.9 182.1ZM31 181.4L36.9 161.9L42.9 181.4ZM40.8 180.7L45.5 167.6L50.3 180.7ZM48.6 180.2L54.6 167.1L60.6 180.2ZM58.4 179.7L62.6 159.4L66.7 179.7ZM65.2 179.4L71.6 155.7L78 179.4ZM75.7 179.1L81.2 159.3L86.8 179.1ZM84.8 179L88.8 165.1L92.9 179ZM91.4 179L95.5 160.7L99.7 179ZM98.2 179.1L102.8 164.8L107.4 179.1ZM105.8 179.2L110.9 166.8L116.1 179.2ZM114.2 179.5L120.3 162.2L126.4 179.5ZM124.2 179.9L129.8 161.7L135.4 179.9ZM133.4 180.4L139.1 162.4L144.7 180.4ZM142.7 181L147.4 163.5L152.1 181ZM150.4 181.6L156.9 157.6L163.4 181.6ZM161 182.4L166.8 160.4L172.6 182.4ZM170.5 183.3L175.1 167.5L179.6 183.3ZM178 183.9L182.2 168.4L186.3 183.9ZM184.8 184.5L189.8 163.3L194.8 184.5ZM193 185.2L198 163.1L203 185.2ZM201.2 185.9L207.3 162.4L213.4 185.9ZM211.2 186.7L215.8 174.7L220.3 186.7ZM218.6 187.2L223.8 164.3L229 187.2ZM227.1 187.7L232.1 164L237.1 187.7ZM235.3 188.2L240.9 175.3L246.5 188.2ZM244.5 188.6L249.1 167.2L253.8 188.6ZM252.1 188.8L257 175.7L261.8 188.8ZM260.1 188.9L265.9 165.4L271.8 188.9ZM269.7 189L274.3 175.6L279 189ZM277.3 188.9L281.4 175.7L285.6 188.9ZM284.1 188.8L288.5 167.3L293 188.8ZM291.4 188.6L296.5 169.9L301.6 188.6ZM299.8 188.3L305.6 174L311.4 188.3ZM309.3 187.8L315 174.2L320.6 187.8ZM318.5 187.2L323.6 173.8L328.6 187.2ZM326.8 186.6L331.5 172.1L336.2 186.6ZM334.5 186L340.5 162.4L346.5 186ZM344.3 185.2L350.6 169.5L356.8 185.2ZM354.5 184.3L359.5 169.8L364.5 184.3ZM362.7 183.6L368.3 161.3L373.9 183.6Z';

function CielEtHorizon() {
  const lointain: [number, number, number, number][] = [[126, 22, 13, 1], [226, 26, 15, 2], [296, 20, 12, 3]];
  return (
    <>
      <rect width={LARGEUR} height={210} fill="url(#tdnm-ciel)" />
      {ETOILES.map(([x, y, rayon], i) => <circle key={i} className={`m-etoile m-d${(i % 3) + 1}`} cx={x} cy={y} r={rayon} fill="#fff" />)}
      <circle cx={304} cy={140} r={34} fill="url(#tdnm-lune)" />
      <circle cx={304} cy={140} r={14} fill="#f6f1dc" />
      <circle cx={299} cy={136} r={3} fill="#e3dcc0" />
      <circle cx={308} cy={145} r={2} fill="#e3dcc0" />
      <path d="M0 186Q60 172 120 178T240 174T360 180V200H0Z" fill="#0a1535" />
      <path d={FORET} fill="#0a1535" />
      {lointain.map(([x, w, h, d]) => (
        <g key={x}>
          <rect x={x} y={178 - h} width={w} height={h + 4} fill="#0c1a40" />
          <polygon points={`${x - 3},${178 - h} ${x + w / 2},${178 - h - 10} ${x + w + 3},${178 - h}`} fill="#0c1a40" />
          <rect className={`m-fen m-d${d}`} x={x + 4} y={178 - h + 4} width={4} height={4.5} fill="#f4c76a" />
          <rect className={`m-fen m-d${(d % 3) + 1}`} x={x + w - 8} y={178 - h + 4} width={4} height={4.5} fill="#f4c76a" />
        </g>
      ))}
    </>
  );
}

/* ------------------------------------------------------------------ village
   « seuil » = rang de la mission (sur 12) dont la validation allume l'élément ;
   il est ramené au nombre réel de missions publiées. */

type Element =
  | { type: 'maison'; x: number; y: number; seuil: number; w: number; h: number; rh: number; d: number; mur?: string }
  | { type: 'eglise' | 'mairie' | 'gsapin'; x: number; y: number; seuil: number }
  | { type: 'chalet'; x: number; y: number; seuil: number; d: number }
  | { type: 'sapin'; x: number; y: number; s: number }
  | { type: 'bonhomme'; x: number; y: number };

/** Triés du plus lointain au plus proche (ordre de dessin). */
const VILLAGE: Element[] = [
  { type: 'chalet', x: 268, y: 250, seuil: 10, d: 1 },
  { type: 'chalet', x: 322, y: 266, seuil: 11, d: 2 },
  { type: 'gsapin', x: 58, y: 268, seuil: 12 },
  { type: 'sapin', x: 150, y: 300, s: 0.7 },
  { type: 'maison', x: 112, y: 324, seuil: 8, w: 42, h: 24, rh: 15, d: 2 },
  { type: 'maison', x: 46, y: 352, seuil: 7, w: 46, h: 26, rh: 16, d: 3, mur: MUR_CLAIR },
  { type: 'maison', x: 328, y: 376, seuil: 9, w: 40, h: 24, rh: 15, d: 1 },
  { type: 'sapin', x: 300, y: 398, s: 0.8 },
  { type: 'sapin', x: 14, y: 420, s: 0.7 },
  { type: 'sapin', x: 196, y: 436, s: 0.75 },
  { type: 'eglise', x: 6, y: 478, seuil: 6 },
  { type: 'mairie', x: 298, y: 480, seuil: 4 },
  { type: 'sapin', x: 346, y: 498, s: 0.9 },
  { type: 'sapin', x: 22, y: 560, s: 1 },
  { type: 'maison', x: 118, y: 562, seuil: 3, w: 44, h: 26, rh: 16, d: 1, mur: MUR_CLAIR },
  { type: 'sapin', x: 348, y: 606, s: 0.9 },
  { type: 'maison', x: 58, y: 610, seuil: 2, w: 50, h: 28, rh: 18, d: 2 },
  { type: 'bonhomme', x: 262, y: 628 },
  { type: 'maison', x: 312, y: 636, seuil: 1, w: 44, h: 26, rh: 16, d: 3 },
  { type: 'sapin', x: 152, y: 640, s: 0.85 },
];

export default function CarteParcours({ etapes, faites, termine, jouable, bravo = null }: Props) {
  const n = etapes.length;
  const { chemin, noeuds } = tracer(n);
  const fraction = (i: number) => (n > 1 ? i / (n - 1) : 0);

  // Première étape pas encore validée : c'est là que se tient le lutin.
  const prochaine = Math.max(etapes.findIndex((e) => e.etat !== 'faite'), 0);
  const iCourante = etapes.findIndex((e) => e.etat === 'courante');
  const iBravo = bravo == null ? -1 : etapes.findIndex((e) => e.numero === bravo && e.etat === 'faite');
  const anime = iBravo !== -1 && iCourante !== -1;

  // Portion dorée du chemin : jusqu'à l'étape en cours (ou la dernière validée si on ne peut pas jouer).
  const fOr = termine ? 1 : fraction(jouable ? prochaine : Math.max(prochaine - 1, 0));
  const fAvant = anime && iBravo < iCourante ? fraction(iBravo) : fOr;

  const seuil = (rang: number) => Math.max(1, Math.round((rang * n) / 12));
  const mode = (rang: number): Mode => {
    const s = seuil(rang);
    if (anime && s === faites) return 'anim';
    return s <= faites ? 'on' : 'off';
  };

  const pLutin = termine || n === 0 ? { x: 134, y: 240 } : aCote(noeuds[prochaine]);
  const depart = anime ? aCote(noeuds[iBravo]) : pLutin;
  const repere = termine || n === 0 ? COFFRE : noeuds[prochaine];

  return (
    <>
      <svg className="tdn-map-svg" viewBox={`0 0 ${LARGEUR} ${HAUTEUR}`} preserveAspectRatio="xMidYMid slice" role="img"
        aria-label={`Carte du parcours : ${faites} mission${faites > 1 ? 's' : ''} validée${faites > 1 ? 's' : ''} sur ${n}`}>
        <defs>
          <linearGradient id="tdnm-ciel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#040b22" /><stop offset="1" stopColor="#10224f" /></linearGradient>
          <linearGradient id="tdnm-sol" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#1b2f6b" /><stop offset=".45" stopColor="#27408a" /><stop offset="1" stopColor="#1a2d68" /></linearGradient>
          <linearGradient id="tdnm-or" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#f6dfa6" /><stop offset="1" stopColor="#cf9f3f" /></linearGradient>
          <linearGradient id="tdnm-rayon" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stopColor="#ffe9ad" stopOpacity=".85" /><stop offset="1" stopColor="#ffe9ad" stopOpacity="0" /></linearGradient>
          <radialGradient id="tdnm-lueur"><stop offset="0" stopColor="#ffd98a" stopOpacity=".55" /><stop offset=".5" stopColor="#f4c76a" stopOpacity=".2" /><stop offset="1" stopColor="#f4c76a" stopOpacity="0" /></radialGradient>
          <radialGradient id="tdnm-lune"><stop offset=".3" stopColor="#f6f1dc" stopOpacity=".35" /><stop offset="1" stopColor="#f6f1dc" stopOpacity="0" /></radialGradient>
        </defs>

        <CielEtHorizon />
        <path d="M0 196Q70 184 150 190T360 188V800H0Z" fill="url(#tdnm-sol)" />
        {[[70, 250, 120, 26, 0.075], [300, 330, 110, 30, 0.07], [60, 520, 120, 34, 0.065], [290, 580, 130, 36, 0.07], [180, 430, 100, 24, 0.055]].map(([cx, cy, rx, ry, o]) => (
          <ellipse key={cy} cx={cx} cy={cy} rx={rx} ry={ry} fill="#fff" opacity={o} />
        ))}

        {/* chemin : trace dans la neige, pointillés, puis portion dorée déjà parcourue */}
        <path d={chemin} fill="none" stroke="#0b1740" strokeWidth={36} strokeLinecap="round" opacity={0.22} transform="translate(0 4)" />
        <path d={chemin} fill="none" stroke="#dfe8ff" strokeWidth={32} strokeLinecap="round" opacity={0.2} />
        <path d={`M${COFFRE.x} ${Y_ARRIVEE}V224`} fill="none" stroke="#dfe8ff" strokeWidth={22} strokeLinecap="round" opacity={0.2} />
        <path d={chemin} fill="none" stroke="#fff" strokeWidth={2.4} strokeLinecap="round" strokeDasharray="1 9" opacity={0.5} />
        {termine ? (
          <>
            <path className="m-or" d={chemin} />
            <path className="m-or" d={`M${COFFRE.x} ${Y_ARRIVEE}V226`} />
          </>
        ) : (fOr > 0 || anime) && (
          <path className={anime ? 'm-or m-b-trace' : 'm-or'} d={chemin} pathLength={1} strokeDasharray={`${r(fOr * 1000) / 1000} 1`}
            style={anime ? ({ '--f0': fAvant, '--f1': fOr } as CSSProperties) : undefined} />
        )}

        {VILLAGE.map((e, i) => {
          switch (e.type) {
            case 'maison': return <Maison key={i} x={e.x} y={e.y} w={e.w} h={e.h} rh={e.rh} d={e.d} mur={e.mur} mode={mode(e.seuil)} />;
            case 'eglise': return <Eglise key={i} x={e.x} y={e.y} mode={mode(e.seuil)} />;
            case 'mairie': return <Mairie key={i} x={e.x} y={e.y} mode={mode(e.seuil)} />;
            case 'chalet': return <Chalet key={i} x={e.x} y={e.y} d={e.d} mode={mode(e.seuil)} />;
            case 'gsapin': return <GrandSapin key={i} x={e.x} y={e.y} mode={mode(e.seuil)} />;
            case 'sapin': return <Sapin key={i} x={e.x} y={e.y} s={e.s} />;
            default: return <Bonhomme key={i} x={e.x} y={e.y} />;
          }
        })}
        {termine && <Guirlandes />}
        <Coffre ouvert={termine} />

        {etapes.map((e, i) => {
          if (anime && i === iBravo) {
            return (
              <g key={e.numero}>
                <Etape p={noeuds[i]} numero={e.numero} etat="courante" className="m-b-avant" />
                <Etape p={noeuds[i]} numero={e.numero} etat="faite" className="m-b-fait" />
              </g>
            );
          }
          if (anime && i === iCourante) {
            return (
              <g key={e.numero}>
                <Etape p={noeuds[i]} numero={e.numero} etat="verrou" />
                <Etape p={noeuds[i]} numero={e.numero} etat="courante" className="m-b-suivante" />
              </g>
            );
          }
          return <Etape key={e.numero} p={noeuds[i]} numero={e.numero} etat={e.etat} />;
        })}

        {anime && Array.from({ length: 8 }, (_, i) => (
          <g key={i} transform={`translate(${r(noeuds[iBravo].x)} ${r(noeuds[iBravo].y)}) rotate(${i * 45})`}><path className="m-b-eclat" d={ECLAT} fill="#ffe9ad" /></g>
        ))}

        <Lutin p={pLutin} className={anime ? 'm-b-marche' : termine ? 'm-fete' : undefined}
          style={anime ? ({ '--dx': `${r(depart.x - pLutin.x)}px`, '--dy': `${r(depart.y - pLutin.y)}px` } as CSSProperties) : undefined} />

        {Array.from({ length: 26 }, (_, i) => (
          <circle key={i} className="m-flocon" cx={((i * 37) % 100) * 3.6} cy={-6} r={1 + ((i * 5) % 3) * 0.5} fill="#fff" opacity={0.35 + ((i * 3) % 5) / 10}
            style={{ animationDuration: `${10 + ((i * 7) % 9)}s`, animationDelay: `-${(i * 13) % 12}s` }} />
        ))}
      </svg>

      <Traineau className="tdn-map-traineau" />

      {/* repère invisible : la page se centre dessus à l'ouverture (voir CentrerEtape) */}
      <span id="tdn-map-repere" className="tdn-map-repere" style={{ left: pc(repere.x, LARGEUR), top: pc(repere.y, HAUTEUR) }} />

      {/* zones cliquables posées sur les étapes : rejouer une mission validée, ouvrir la mission en cours */}
      {etapes.map((e, i) => {
        if (e.etat === 'verrou') return null;
        return (
          <Link key={e.numero} href={`/tresors-de-noel/mission/${e.numero}`} className="tdn-map-lien"
            style={{ left: pc(noeuds[i].x, LARGEUR), top: pc(noeuds[i].y, HAUTEUR) }}
            aria-label={e.etat === 'courante' ? `Jouer la mission ${e.numero} : ${e.titre}` : `Revoir la mission ${e.numero} : ${e.titre}`} />
        );
      })}

      {anime && <p className="tdn-map-bravo" role="status">Mission accomplie !</p>}
    </>
  );
}
