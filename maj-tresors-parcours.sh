#!/usr/bin/env bash
# Trésors de Noël : la page « Mon aventure » devient une carte du village (chemin, étapes, lutin, coffre)
# avec l'animation « mission accomplie » jouée après chaque bonne réponse.
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/CarteParcours.tsx' <<'EOF_PN_FICHIER'
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
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/CarteParcours.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/CentrerEtape.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useEffect } from 'react';

/**
 * La carte du parcours est plus haute que l'écran d'un téléphone : à l'ouverture de la page,
 * on fait défiler jusqu'au repère posé sur l'étape en cours (ou sur le coffre, à la fin).
 */
export default function CentrerEtape({ cle }: { cle: string }) {
  useEffect(() => {
    document.getElementById('tdn-map-repere')?.scrollIntoView({ block: 'center' });
  }, [cle]);
  return null;
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/CentrerEtape.tsx"
mkdir -p 'src/app/tresors-de-noel/aventure'
cat > 'src/app/tresors-de-noel/aventure/page.tsx' <<'EOF_PN_FICHIER'
import type { ReactNode } from 'react';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import NavTresors from '@/components/tresors/NavTresors';
import SelecteurParticipant from '@/components/tresors/SelecteurParticipant';
import CarteParcours, { type EtapeCarte } from '@/components/tresors/CarteParcours';
import CentrerEtape from '@/components/tresors/CentrerEtape';
import { contexteJoueur, dateFr, jeuOuvert, lireMissions, lireReglages } from '@/lib/tresors/db';

/**
 * « Mon aventure » : la progression est une carte du village. Le chemin relie les missions,
 * le lutin avance d'étape en étape et le village s'illumine au fil des missions validées.
 * ?bravo=N (posé par l'écran de mission après une bonne réponse) joue l'animation « mission accomplie ».
 */
export default async function PageAventure({ searchParams }: { searchParams: Promise<{ bravo?: string }> }) {
  const [{ bravo }, ctx] = await Promise.all([searchParams, contexteJoueur()]);
  if (!ctx) redirect('/tresors-de-noel/acces');
  const [missions, r] = await Promise.all([lireMissions(), lireReglages()]);
  const actif = ctx.actif;

  if (!actif) {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Aucun participant</h1>
        <p className="tdn-p">Ajoutez des participants depuis votre compte.</p>
        <Link href="/tresors-de-noel/compte" className="tdn-btn tdn-btn-or">Mon compte</Link>
        <NavTresors />
      </main>
    );
  }

  const prenom = actif.participant.prenom;
  const validees = new Set(actif.missionsValidees);
  const faites = missions.filter((m) => validees.has(m.id)).length;
  const termine = missions.length > 0 && faites === missions.length;
  const jouable = actif.participant.paye && jeuOuvert(r);
  const mission = missions.find((m) => !validees.has(m.id));

  const etapes: EtapeCarte[] = missions.map((m) => ({
    numero: m.numero,
    titre: m.titre,
    etat: validees.has(m.id) ? 'faite' : jouable && m.id === mission?.id ? 'courante' : 'verrou',
  }));
  const numeroBravo = Number(bravo);

  // Fiche du bas : ce qu'il y a à faire maintenant.
  let fiche: ReactNode;
  if (!actif.participant.paye) {
    fiche = (
      <>
        <div>
          <p className="tdn-map-fnum">Paiement en attente</p>
          <h2 className="tdn-map-ftitre">La participation de {prenom} n&apos;est pas encore réglée</h2>
        </div>
        <Link href="/tresors-de-noel/compte" className="tdn-map-jouer">Régler</Link>
      </>
    );
  } else if (termine) {
    fiche = (
      <>
        <div>
          <p className="tdn-map-fnum">Aventure terminée</p>
          <h2 className="tdn-map-ftitre">Le coffre est ouvert</h2>
          <p className="tdn-map-flieu">Les {missions.length} mystères sont résolus</p>
        </div>
        <Link href="/tresors-de-noel/cle" className="tdn-map-jouer">Voir ma clé</Link>
      </>
    );
  } else if (!jouable) {
    const cloture = !!r.jeu_fin && new Date() > new Date(r.jeu_fin);
    fiche = cloture ? (
      <div>
        <p className="tdn-map-fnum">Jeu terminé</p>
        <h2 className="tdn-map-ftitre">L&apos;aventure s&apos;est achevée le {dateFr(r.jeu_fin)}</h2>
      </div>
    ) : (
      <div>
        <p className="tdn-map-fnum">Votre place est réservée</p>
        <h2 className="tdn-map-ftitre">L&apos;aventure commence le {dateFr(r.jeu_debut)}</h2>
        <p className="tdn-map-flieu">{r.periode_texte}</p>
      </div>
    );
  } else if (mission) {
    fiche = (
      <>
        <div>
          <p className="tdn-map-fnum">Mission {mission.numero}</p>
          <h2 className="tdn-map-ftitre">« {mission.titre} »</h2>
          {mission.lieu && <p className="tdn-map-flieu">📍 {mission.lieu}</p>}
        </div>
        <Link href={`/tresors-de-noel/mission/${mission.numero}`} className="tdn-map-jouer">Jouer</Link>
      </>
    );
  } else {
    fiche = (
      <div>
        <p className="tdn-map-fnum">Bientôt</p>
        <h2 className="tdn-map-ftitre">Les missions arrivent</h2>
      </div>
    );
  }

  return (
    <main className="tdn-map-page">
      <header className="tdn-map-entete">
        <div className="tdn-map-ligne">
          <h1 className="tdn-map-bonjour">Bonjour {prenom}</h1>
          <span className="tdn-map-score" aria-label={`${faites} missions validées sur ${missions.length}`}>
            <b aria-hidden="true">✦</b> {faites} / {missions.length}
          </span>
        </div>
        <SelecteurParticipant progressions={ctx.progressions} actifId={actif.participant.id} />
      </header>

      <div className="tdn-map">
        <CarteParcours etapes={etapes} faites={faites} termine={termine} jouable={jouable}
          bravo={Number.isInteger(numeroBravo) && numeroBravo > 0 ? numeroBravo : null} />
      </div>

      <div className="tdn-map-bas">
        <section className="tdn-map-fiche">{fiche}</section>
      </div>

      <CentrerEtape cle={`${actif.participant.id}-${faites}`} />
      <NavTresors />
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-de-noel/aventure/page.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/Mission.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import BlocMission from './BlocMission';
import Indices from './Indices';
import { validerReponse } from '@/app/tresors-actions';
import type { MissionPublique, Progression } from '@/lib/tresors/types';

/** Mission générique : contenu, question, validation multi-participants (côté serveur), indices.
 *  Après une bonne réponse, « Continuer » renvoie sur la carte avec ?bravo=N pour y jouer l'animation. */
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
        <button className="tdn-btn tdn-btn-or tdn-btn-large" onClick={() => router.push(aTermine ? '/tresors-de-noel/fin' : `/tresors-de-noel/aventure?bravo=${m.numero}`)}>Continuer</button>
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
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/Mission.tsx"
mkdir -p 'src/app/tresors-de-noel'
cat > 'src/app/tresors-de-noel/tresors.css' <<'EOF_PN_FICHIER'
/* =========================================================
   LES TRÉSORS DE NOËL — feuille dédiée, préfixe .tdn
   Palette : bleu nuit, blanc neige, doré chaud, bordeaux, sapin.
   Mobile-first ; les styles globaux du site ne sont pas modifiés.
   ========================================================= */
@import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,500;0,600;0,700;1,500&display=swap');

.tdn{
  --tdn-nuit:#081430; --tdn-nuit-2:#0f2150; --tdn-nuit-3:#172c63;
  --tdn-creme:#fbf7ef; --tdn-neige:#ffffff; --tdn-or:#e5c07b; --tdn-or-2:#c99a3b;
  --tdn-bordeaux:#8a2a3a; --tdn-sapin:#1f5c45; --tdn-texte:#e9e4d8; --tdn-muted:#a9b3cc;
  --tdn-ombre:0 12px 40px rgba(0,0,0,.35);
  --tdn-radius:18px;
  min-height:100vh; background:var(--tdn-nuit); color:var(--tdn-texte);
  font-family:'Bricolage Grotesque',system-ui,sans-serif; -webkit-font-smoothing:antialiased;
  overflow-x:hidden;
}
.tdn *{box-sizing:border-box;}
.tdn :where(h1,h2,h3){text-transform:none;letter-spacing:0;font-family:'Bricolage Grotesque',system-ui,sans-serif;font-weight:700;}
.tdn :where(section){padding:0;}
.tdn :where(footer){background:transparent;padding:0;display:block;color:inherit;}
.tdn a{color:inherit;}
.tdn button{font-family:inherit;}
.tdn-titre-fee{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;line-height:1.05;letter-spacing:.005em;}
.tdn-sur{font-family:'DM Mono',ui-monospace,monospace;text-transform:uppercase;letter-spacing:.16em;
  font-size:.66rem;color:var(--tdn-or);}
.tdn-sur-grand{font-size:.85rem;}
.tdn-muted{color:var(--tdn-muted);}
.tdn-mini{font-size:.8rem;}
.tdn-sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);}
.tdn-fond-nuit{background:var(--tdn-nuit);}
.tdn-p{max-width:40ch;margin:0 auto 1.4rem;line-height:1.55;}
.tdn-centre{text-align:center;display:flex;flex-direction:column;align-items:center;}

/* ---------- Décor : étoiles, neige, village, halo ---------- */
.tdn-etoiles{position:absolute;inset:0;pointer-events:none;opacity:.8;
  background-image:
    radial-gradient(1px 1px at 12% 18%,#fff 60%,transparent 61%),
    radial-gradient(1.5px 1.5px at 78% 12%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 40% 32%,#fff 60%,transparent 61%),
    radial-gradient(1.2px 1.2px at 88% 40%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 25% 55%,#fff 60%,transparent 61%),
    radial-gradient(1.5px 1.5px at 60% 22%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 5% 70%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 50% 8%,#fff 60%,transparent 61%),
    radial-gradient(1.2px 1.2px at 95% 66%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 70% 48%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 33% 78%,#fff 60%,transparent 61%);
  animation:tdn-etoile 5s ease-in-out infinite alternate;}
@keyframes tdn-etoile{from{opacity:.55}to{opacity:.95}}
.tdn-neige{position:absolute;inset:0;overflow:hidden;pointer-events:none;}
.tdn-neige i{position:absolute;top:-10px;border-radius:50%;background:#fff;
  animation:tdn-chute linear infinite;}
@keyframes tdn-chute{to{transform:translateY(110vh) translateX(18px);}}
.tdn-village{position:absolute;left:0;right:0;bottom:0;width:100%;height:auto;display:block;pointer-events:none;}
.tdn-fenetre{animation:tdn-fenetre 3s ease-in-out infinite alternate;}
@keyframes tdn-fenetre{from{opacity:.55}to{opacity:1}}
.tdn-halo{position:absolute;left:50%;top:38%;width:70vmin;height:70vmin;transform:translate(-50%,-50%);
  border-radius:50%;pointer-events:none;
  background:radial-gradient(circle,rgba(229,192,123,.28) 0%,rgba(229,192,123,.08) 40%,transparent 70%);
  animation:tdn-halo 4s ease-in-out infinite alternate;}
@keyframes tdn-halo{from{transform:translate(-50%,-50%) scale(.9)}to{transform:translate(-50%,-50%) scale(1.08)}}

/* ---------- Intro ---------- */
.tdn-intro{position:fixed;inset:0;z-index:50;background:radial-gradient(ellipse at 50% 20%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);
  display:flex;align-items:center;justify-content:center;overflow:hidden;
  transition:opacity .7s ease;}
.tdn-intro.sortie{opacity:0;pointer-events:none;}
.tdn-traineau{position:absolute;top:14%;left:-340px;width:clamp(200px,45vw,320px);height:auto;color:rgba(251,247,239,.7);
  filter:drop-shadow(0 0 14px rgba(229,192,123,.45));animation:tdn-traineau 10s ease-in-out 1.2s forwards;}
@keyframes tdn-traineau{0%{left:-340px;top:18%;opacity:0}8%{opacity:1}92%{opacity:1}100%{left:110%;top:6%;opacity:0}}
.tdn-intro-texte{position:relative;z-index:2;padding:0 1.6rem;text-align:center;max-width:36rem;}
.tdn-intro-phrase{font-family:'Cormorant Garamond',Georgia,serif;font-size:clamp(1.6rem,6vw,2.6rem);
  font-weight:500;font-style:italic;line-height:1.25;color:var(--tdn-creme);
  animation:tdn-fondu 2.3s ease-in-out both;}
@keyframes tdn-fondu{0%{opacity:0;transform:translateY(10px)}20%{opacity:1;transform:none}80%{opacity:1}100%{opacity:0;transform:translateY(-8px)}}
.tdn-intro-titre{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;
  font-size:clamp(2.1rem,8.5vw,4rem);line-height:1.05;color:var(--tdn-or);
  text-shadow:0 0 30px rgba(229,192,123,.45);animation:tdn-apparait 1.6s ease-out both;}
@keyframes tdn-apparait{from{opacity:0;transform:scale(.94);filter:blur(6px)}to{opacity:1;transform:none;filter:none}}
.tdn-scintille{display:inline-block;margin:0 .4em;font-size:.55em;vertical-align:middle;color:var(--tdn-creme);
  animation:tdn-scintille 1.4s ease-in-out infinite;}
.tdn-scintille-2{animation-delay:.7s;}
@keyframes tdn-scintille{0%,100%{opacity:.3;transform:scale(.7)}50%{opacity:1;transform:scale(1.15)}}
.tdn-passer{position:absolute;right:1rem;bottom:calc(1rem + env(safe-area-inset-bottom));z-index:3;
  background:rgba(8,20,48,.5);color:var(--tdn-muted);border:1px solid rgba(255,255,255,.18);
  padding:.7rem 1.1rem;border-radius:999px;font-size:.8rem;cursor:pointer;backdrop-filter:blur(6px);}
.tdn-passer:hover{color:var(--tdn-creme);border-color:var(--tdn-or);}

/* ---------- Landing ---------- */
.tdn-landing{padding-bottom:5.5rem;}
.tdn-hero{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;
  padding:5rem 1.4rem 9rem;overflow:hidden;text-align:center;
  background:radial-gradient(ellipse at 50% 15%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);}
.tdn-hero-inner{position:relative;z-index:2;max-width:38rem;}
.tdn-hero h1{font-size:clamp(2.4rem,10vw,4.6rem);color:var(--tdn-or);margin:.8rem 0 1rem;
  text-shadow:0 0 40px rgba(229,192,123,.35);}
.tdn-hero-accroche{font-family:'Cormorant Garamond',Georgia,serif;font-style:italic;font-size:1.35rem;color:var(--tdn-creme);}
.tdn-hero-texte{margin:1rem auto 1.8rem;max-width:34ch;line-height:1.55;color:var(--tdn-texte);}
.tdn-cta{display:flex;flex-direction:column;gap:1rem;align-items:stretch;margin-top:1.4rem;}
@media(min-width:560px){.tdn-cta{flex-direction:row;justify-content:center;}}

.tdn-section{padding:2.5rem 1.2rem;max-width:44rem;margin:0 auto;}
.tdn-h2{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:2.1rem;color:var(--tdn-or);
  text-align:center;margin-bottom:1.5rem;}
.tdn-tresor .tdn-h2{margin-bottom:.2rem;}
.tdn-resume{list-style:none;padding:0;margin:0;display:grid;grid-template-columns:1fr 1fr;gap:.7rem;}
@media(min-width:640px){.tdn-resume{grid-template-columns:repeat(3,1fr);}}
.tdn-resume li{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:var(--tdn-radius);
  padding:1rem .9rem;display:flex;flex-direction:column;gap:.25rem;}
.tdn-resume-ico{font-size:1.4rem;}
.tdn-resume b{font-size:.95rem;color:var(--tdn-creme);}
.tdn-resume small{color:var(--tdn-muted);font-size:.78rem;line-height:1.35;}
.tdn-etapes{list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:.6rem;}
.tdn-etapes li{display:flex;gap:.9rem;align-items:flex-start;background:rgba(255,255,255,.05);
  border:1px solid rgba(255,255,255,.1);border-radius:var(--tdn-radius);padding:1rem;}
.tdn-etapes b{display:block;color:var(--tdn-creme);}
.tdn-etapes small{color:var(--tdn-muted);line-height:1.4;}
.tdn-etape-n{flex:0 0 2.2rem;height:2.2rem;border-radius:50%;display:grid;place-items:center;
  background:var(--tdn-nuit-3);color:var(--tdn-or);font-weight:700;border:1px solid rgba(229,192,123,.4);}
.tdn-etape-speciale{background:linear-gradient(135deg,rgba(229,192,123,.22),rgba(138,42,58,.25))!important;
  border-color:rgba(229,192,123,.5)!important;}
.tdn-pied{display:flex;justify-content:space-between;gap:1rem;flex-wrap:wrap;padding:2rem 1.4rem;
  color:var(--tdn-muted);font-size:.8rem;border-top:1px solid rgba(255,255,255,.08);}

/* ---------- Boutons ---------- */
.tdn-btn{display:inline-flex;align-items:center;justify-content:center;gap:.5rem;min-height:3.25rem;
  padding:.9rem 1.5rem;border-radius:999px;font-weight:700;font-size:1rem;text-decoration:none;
  border:2px solid transparent;cursor:pointer;transition:transform .12s,box-shadow .12s,background .15s;
  -webkit-tap-highlight-color:transparent;}
.tdn-btn:active{transform:scale(.98);}
.tdn-btn:disabled{opacity:.45;cursor:not-allowed;}
.tdn-btn-or{background:linear-gradient(135deg,var(--tdn-or),var(--tdn-or-2));color:var(--tdn-nuit);
  box-shadow:0 8px 24px rgba(229,192,123,.3);}
.tdn-btn-or:hover:not(:disabled){box-shadow:0 10px 30px rgba(229,192,123,.45);}
.tdn-btn-ghost{background:transparent;color:var(--tdn-creme);border-color:rgba(255,255,255,.3);}
.tdn-btn-ghost:hover:not(:disabled){border-color:var(--tdn-or);color:var(--tdn-or);}
.tdn-btn-nuit{background:var(--tdn-nuit);color:var(--tdn-or);}
.tdn-btn-large{width:100%;margin-top:1rem;}
.tdn-btn-xl{width:100%;min-height:4rem;font-size:1.3rem;text-transform:uppercase;letter-spacing:.06em;}
.tdn-lien{background:none;border:none;color:var(--tdn-muted);text-decoration:underline;cursor:pointer;
  font-size:.9rem;padding:.6rem 0;font-family:inherit;}
.tdn-lien:hover{color:var(--tdn-or);}
.tdn-mini-lien{margin-left:auto;font-size:.8rem;color:var(--tdn-or);text-decoration:none;align-self:center;padding:.4rem;}
.tdn-actions{display:flex;gap:.7rem;margin-top:1rem;}
.tdn-actions .tdn-btn{flex:1;}
.tdn-actions-col{flex-direction:column;}

/* ---------- Pages internes ---------- */
.tdn-page{max-width:36rem;margin:0 auto;padding:1rem 1rem 6.5rem;min-height:100svh;}
.tdn-entete{display:flex;align-items:center;gap:.8rem;padding:.6rem 0 1.2rem;}
.tdn-entete h1{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:1.9rem;line-height:1.05;color:var(--tdn-creme);}
.tdn-retour{flex:0 0 2.8rem;height:2.8rem;border-radius:50%;display:grid;place-items:center;
  background:rgba(255,255,255,.08);text-decoration:none;font-size:1.2rem;color:var(--tdn-creme);}
.tdn-carte{background:rgba(255,255,255,.055);border:1px solid rgba(255,255,255,.1);border-radius:var(--tdn-radius);
  padding:1.3rem 1.2rem;margin-bottom:1rem;}
.tdn-carte h2{font-size:1.2rem;color:var(--tdn-creme);margin-bottom:.6rem;}
.tdn-carte p{line-height:1.55;}
.tdn-carte .tdn-titre-fee{font-size:1.9rem;color:var(--tdn-or);margin:.3rem 0 .5rem;}
.tdn-or{background:linear-gradient(135deg,rgba(229,192,123,.22),rgba(201,154,59,.12));border-color:rgba(229,192,123,.5);}
.tdn-regles article p{color:var(--tdn-texte);margin-top:.3rem;}
.tdn-lieu{color:var(--tdn-or);font-weight:600;margin-bottom:.6rem;}
.tdn-liste-num{padding-left:1.3rem;line-height:1.7;}

/* Formulaires */
.tdn-champ{margin-bottom:.9rem;}
.tdn-champ label{display:block;font-family:'DM Mono',monospace;font-size:.66rem;letter-spacing:.14em;
  text-transform:uppercase;color:var(--tdn-muted);margin-bottom:.4rem;}
.tdn-champ input{width:100%;min-height:3.25rem;padding:.8rem 1rem;border-radius:12px;font-size:1.05rem;
  background:rgba(8,20,48,.6);border:2px solid rgba(255,255,255,.18);color:var(--tdn-creme);font-family:inherit;}
.tdn-champ input::placeholder{color:rgba(169,179,204,.6);}
.tdn-champ input:focus{outline:none;border-color:var(--tdn-or);box-shadow:0 0 0 4px rgba(229,192,123,.2);}
.tdn-champ-grand input{font-size:1.8rem;text-align:center;min-height:4.2rem;font-family:'DM Mono',monospace;letter-spacing:.1em;}
.tdn-champ-grand label{font-size:.9rem;text-align:center;}
.tdn-code-input{font-family:'DM Mono',monospace;font-size:1.8rem!important;text-align:center;letter-spacing:.35em;}
.tdn-stepper{display:flex;gap:.4rem;margin-bottom:1.2rem;}
.tdn-stepper span{flex:1;height:5px;border-radius:5px;background:rgba(255,255,255,.12);}
.tdn-stepper span.on{background:var(--tdn-or);}
.tdn-ligne-part{display:flex;gap:.6rem;align-items:flex-end;}
.tdn-toggle{display:flex;border:2px solid rgba(255,255,255,.18);border-radius:12px;overflow:hidden;margin-bottom:.9rem;}
.tdn-toggle button{background:transparent;border:none;color:var(--tdn-muted);padding:0 .9rem;min-height:3.25rem;cursor:pointer;font-weight:600;}
.tdn-toggle button.on{background:var(--tdn-or);color:var(--tdn-nuit);}
.tdn-toggle button:disabled{opacity:.35;cursor:not-allowed;}
.tdn-suppr{flex:0 0 2.6rem;height:3.25rem;margin-bottom:.9rem;background:transparent;border:2px solid rgba(255,255,255,.18);
  border-radius:12px;color:var(--tdn-muted);cursor:pointer;font-size:1rem;}
.tdn-suppr:hover{border-color:var(--tdn-bordeaux);color:#f0a0ae;}
.tdn-suppr:disabled{opacity:.3;cursor:not-allowed;border-color:rgba(255,255,255,.18);color:var(--tdn-muted);}
/* Règle « au moins un adulte pour inscrire des enfants » */
.tdn-regle-adulte{margin:.2rem 0 1rem;padding:.6rem .8rem;border-left:3px solid var(--tdn-or);border-radius:0 10px 10px 0;background:rgba(229,192,123,.1);font-size:.88rem;color:var(--tdn-texte);}
.tdn-regle-adulte b{color:var(--tdn-or);}
.tdn-recap{list-style:none;padding:0;margin:1rem 0;}
.tdn-recap li{display:flex;justify-content:space-between;padding:.7rem 0;border-bottom:1px solid rgba(255,255,255,.1);}
.tdn-recap small{color:var(--tdn-muted);}
.tdn-recap-total{font-size:1.2rem;color:var(--tdn-or);border-bottom:none!important;}
.tdn-succes{width:4.5rem;height:4.5rem;border-radius:50%;display:grid;place-items:center;margin:3rem auto 1.5rem;
  background:var(--tdn-sapin);color:#fff;font-size:2rem;font-weight:700;box-shadow:0 0 40px rgba(31,92,69,.6);}
.tdn-centre .tdn-titre-fee{font-size:2.2rem;color:var(--tdn-or);margin-bottom:1rem;}

/* Compte / participants */
.tdn-participants{list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:.6rem;}
.tdn-participants li{display:flex;gap:.5rem;align-items:center;}
.tdn-part-sel{flex:1;display:flex;gap:.9rem;align-items:center;text-align:left;background:rgba(8,20,48,.5);
  border:2px solid rgba(255,255,255,.12);border-radius:14px;padding:.8rem;cursor:pointer;color:inherit;}
.tdn-participants li.on .tdn-part-sel{border-color:var(--tdn-or);}
.tdn-avatar{flex:0 0 2.6rem;height:2.6rem;border-radius:50%;display:grid;place-items:center;font-weight:700;
  background:var(--tdn-nuit-3);color:var(--tdn-or);font-family:'Cormorant Garamond',serif;font-size:1.4rem;}
.tdn-part-info{flex:1;display:flex;flex-direction:column;gap:.2rem;}
.tdn-part-info b{color:var(--tdn-creme);}
.tdn-part-info small{color:var(--tdn-muted);font-size:.78rem;}
.tdn-participants .tdn-suppr{margin-bottom:0;height:2.6rem;}
.tdn-pastille{font-family:'DM Mono',monospace;font-size:.62rem;letter-spacing:.12em;text-transform:uppercase;
  padding:.3rem .6rem;border-radius:999px;background:rgba(229,192,123,.18);color:var(--tdn-or);white-space:nowrap;}
.tdn-pastille-ok{background:rgba(31,92,69,.35);color:#9fe0c0;}

/* Progression */
.tdn-compteur{font-size:1.1rem;margin:.3rem 0 .6rem;color:var(--tdn-creme);}
.tdn-compteur b{font-family:'Cormorant Garamond',serif;font-size:2.6rem;color:var(--tdn-or);line-height:1;}
.tdn-barre{height:12px;border-radius:12px;background:rgba(255,255,255,.1);overflow:hidden;}
.tdn-barre i{display:block;height:100%;border-radius:12px;background:linear-gradient(90deg,var(--tdn-or-2),var(--tdn-or));
  transition:width .6s ease;box-shadow:0 0 12px rgba(229,192,123,.6);}
.tdn-barre-mini{height:6px;margin:.2rem 0;}
.tdn-switch{margin-top:1.1rem;}
.tdn-chips{display:flex;gap:.5rem;flex-wrap:wrap;margin-top:.5rem;}
.tdn-chips button{min-height:2.8rem;padding:0 1.1rem;border-radius:999px;cursor:pointer;font-weight:600;
  background:rgba(255,255,255,.07);border:2px solid rgba(255,255,255,.15);color:var(--tdn-texte);}
.tdn-chips button.on{background:var(--tdn-or);border-color:var(--tdn-or);color:var(--tdn-nuit);}
.tdn-mission-carte{padding:1.6rem 1.3rem;}
.tdn-parcours{list-style:none;padding:0;margin:0;}
.tdn-parcours li{display:flex;gap:.8rem;align-items:center;padding:.55rem 0;border-bottom:1px solid rgba(255,255,255,.07);color:var(--tdn-muted);}
.tdn-parcours li:last-child{border-bottom:none;}
.tdn-parcours b{display:block;font-size:.95rem;}
.tdn-parcours small{font-size:.75rem;}
.tdn-parcours li.ok .tdn-etape-n{background:var(--tdn-sapin);color:#fff;border-color:transparent;}
.tdn-parcours li.ok b{color:var(--tdn-creme);}
.tdn-parcours li.now{color:var(--tdn-creme);}
.tdn-parcours li.now .tdn-etape-n{background:var(--tdn-or);color:var(--tdn-nuit);}

/* Mission */
.tdn-recit{font-family:'Cormorant Garamond',Georgia,serif;font-size:1.25rem;line-height:1.45;color:var(--tdn-creme);margin-bottom:1rem;}
.tdn-media{margin:0 0 1rem;}
.tdn-media-img{border-radius:14px;overflow:hidden;border:1px solid rgba(255,255,255,.12);}
.tdn-media-img svg{display:block;width:100%;height:auto;}
.tdn-media-video{aspect-ratio:16/9;display:grid;place-items:center;background:linear-gradient(135deg,var(--tdn-nuit-3),var(--tdn-nuit));}
.tdn-media figcaption{font-size:.8rem;color:var(--tdn-muted);margin-top:.4rem;}
.tdn-media-ligne{display:flex;gap:.8rem;align-items:center;background:rgba(8,20,48,.6);border-radius:14px;padding:.8rem;}
.tdn-media-ligne b{display:block;font-size:.9rem;color:var(--tdn-creme);}
.tdn-media-ligne small{color:var(--tdn-muted);font-size:.75rem;}
.tdn-play{flex:0 0 2.6rem;height:2.6rem;border-radius:50%;display:grid;place-items:center;background:var(--tdn-or);color:var(--tdn-nuit);font-size:.9rem;padding-left:.2rem;}
.tdn-play-grand{width:4rem;height:4rem;font-size:1.5rem;}
.tdn-onde{margin-left:auto;display:flex;gap:2px;align-items:center;height:1.6rem;}
.tdn-onde i{width:3px;background:var(--tdn-or);border-radius:2px;opacity:.7;}
.tdn-question{font-size:1.15rem;font-weight:600;color:var(--tdn-creme);margin:.3rem 0 1rem;}
.tdn-choix{display:flex;flex-direction:column;gap:.55rem;}
.tdn-choix button{min-height:3.25rem;padding:.8rem 1rem;border-radius:12px;text-align:left;font-size:1rem;cursor:pointer;
  background:rgba(8,20,48,.6);border:2px solid rgba(255,255,255,.18);color:var(--tdn-creme);}
.tdn-choix button.on{border-color:var(--tdn-or);background:rgba(229,192,123,.15);}
.tdn-erreur{color:#f4a9b6;background:rgba(138,42,58,.25);border:1px solid rgba(138,42,58,.6);border-radius:12px;padding:.7rem .9rem;margin-top:.6rem;font-weight:600;}
.tdn-fieldset{border:1px solid rgba(255,255,255,.14);border-radius:12px;padding:.8rem 1rem .4rem;margin-top:1.2rem;}
.tdn-fieldset legend{padding:0 .4rem;}
.tdn-check{display:flex;align-items:center;gap:.8rem;min-height:2.8rem;font-size:1rem;cursor:pointer;}
.tdn-check input{width:1.4rem;height:1.4rem;accent-color:var(--tdn-or);}
.tdn-check-off{color:var(--tdn-muted);}
.tdn-check small{color:var(--tdn-muted);}
.tdn-indices{margin-top:1.4rem;padding:1.2rem;border-radius:var(--tdn-radius);border:1px dashed rgba(229,192,123,.4);}
.tdn-indices h3{font-size:1.05rem;color:var(--tdn-or);margin-bottom:.8rem;}
.tdn-indices .tdn-btn{width:100%;margin-top:.4rem;}
.tdn-indice{background:rgba(229,192,123,.1);border-radius:12px;padding:.8rem .9rem;margin-bottom:.6rem;animation:tdn-apparait .5s ease both;}
.tdn-indice p{margin-top:.25rem;color:var(--tdn-creme);}
.tdn-indice-secours{background:rgba(138,42,58,.2);}
.tdn-reussite{text-align:center;padding:2.2rem 1.3rem;border-color:rgba(229,192,123,.5);animation:tdn-apparait .6s ease both;}
.tdn-eclat{font-size:3rem;color:var(--tdn-or);animation:tdn-scintille 1.6s ease-in-out infinite;text-shadow:0 0 30px rgba(229,192,123,.7);}

/* Clé */
.tdn-cle{position:relative;overflow:hidden;border-radius:22px;padding:1.4rem;color:var(--tdn-nuit);
  background:linear-gradient(150deg,#f6e3b5 0%,var(--tdn-or) 40%,#b98a30 100%);
  box-shadow:0 20px 50px rgba(0,0,0,.45),inset 0 1px 0 rgba(255,255,255,.6);}
.tdn-cle .tdn-sur{color:rgba(8,20,48,.6);}
.tdn-cle-brillance{position:absolute;inset:-60%;pointer-events:none;
  background:linear-gradient(115deg,transparent 40%,rgba(255,255,255,.55) 50%,transparent 60%);
  animation:tdn-brillance 4.5s ease-in-out infinite;}
@keyframes tdn-brillance{0%{transform:translateX(-60%)}60%,100%{transform:translateX(60%)}}
.tdn-cle-haut{display:flex;justify-content:space-between;align-items:center;margin-bottom:.8rem;}
.tdn-cle .tdn-pastille{background:rgba(8,20,48,.15);color:var(--tdn-nuit);}
.tdn-cle .tdn-pastille-ok{background:var(--tdn-sapin);color:#fff;}
.tdn-cle-icone{width:4rem;height:2rem;color:var(--tdn-nuit);margin-bottom:.4rem;}
.tdn-cle-icone-vide{width:5rem;height:2.5rem;color:var(--tdn-or);opacity:.6;margin:1rem auto;}
.tdn-cle-num{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:2.4rem;line-height:1;margin-bottom:.8rem;}
.tdn-cle-code{font-family:'DM Mono',monospace;font-size:1.9rem;letter-spacing:.14em;margin:.2rem 0 1rem;font-weight:500;}
.tdn-cle-bas{display:flex;justify-content:space-between;align-items:flex-end;gap:1rem;border-top:1px solid rgba(8,20,48,.2);padding-top:.9rem;}
.tdn-cle-bas b{display:block;font-size:1rem;}
.tdn-cle-bas small{display:block;font-size:.72rem;color:rgba(8,20,48,.7);}
.tdn-qr{width:5.2rem;height:5.2rem;color:var(--tdn-nuit);background:var(--tdn-creme);padding:.3rem;border-radius:8px;flex:0 0 auto;}
.tdn-cle-grande{padding:1.7rem 1.5rem;}

/* Fin */
.tdn-fin{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;
  padding:2rem 1.2rem;overflow:hidden;
  background:radial-gradient(ellipse at 50% 30%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);}
.tdn-fin-inner{position:relative;z-index:2;width:100%;max-width:30rem;text-align:center;}
.tdn-fin-texte{font-size:clamp(2rem,8vw,3rem);color:var(--tdn-or);animation:tdn-apparait 1.2s ease both;text-shadow:0 0 30px rgba(229,192,123,.4);}
.tdn-lumiere-or{position:absolute;inset:0;pointer-events:none;
  background:radial-gradient(circle at 50% 55%,rgba(229,192,123,.45) 0%,rgba(229,192,123,.12) 30%,transparent 60%);
  animation:tdn-lumiere 2s ease-out both;}
@keyframes tdn-lumiere{from{opacity:0;transform:scale(.4)}to{opacity:1;transform:scale(1)}}
.tdn-fin-cle{animation:tdn-apparait 1s ease both;}
.tdn-fin-cle .tdn-cle{text-align:left;margin:1.5rem 0;}
.tdn-fin-msg{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:1.25rem;color:var(--tdn-creme);line-height:1.4;margin:1rem 0;}

/* Coffre (CSS pur) */
.tdn-coffre-scene{display:flex;flex-direction:column;align-items:center;gap:1.6rem;}
.tdn-coffre{position:relative;width:150px;height:110px;}
.tdn-coffre-xl{width:260px;height:190px;}
.tdn-coffre i{position:absolute;display:block;}
.tdn-coffre-corps{left:0;right:0;bottom:0;height:60%;background:linear-gradient(180deg,#6b2431,var(--tdn-bordeaux));
  border:3px solid var(--tdn-or);border-radius:0 0 12px 12px;box-shadow:inset 0 -10px 0 rgba(0,0,0,.25);}
.tdn-coffre-corps::after{content:"";position:absolute;left:50%;top:-2px;width:22%;height:40%;transform:translateX(-50%);
  background:var(--tdn-or);border-radius:0 0 6px 6px;}
.tdn-coffre-couvercle{left:0;right:0;top:0;height:44%;background:linear-gradient(180deg,#8a2a3a,#6b2431);
  border:3px solid var(--tdn-or);border-radius:60px 60px 0 0;transform-origin:50% 100%;transition:transform .9s cubic-bezier(.2,.8,.2,1);z-index:2;}
.tdn-coffre.ouvert .tdn-coffre-couvercle{transform:rotateX(-110deg) translateY(-8px);}
.tdn-coffre-lueur{left:10%;right:10%;top:20%;height:40%;border-radius:50%;opacity:0;
  background:radial-gradient(ellipse,rgba(255,236,180,.95),rgba(229,192,123,.4) 50%,transparent 75%);
  filter:blur(6px);transition:opacity .6s .5s,transform .8s .5s;transform:scale(.6);}
.tdn-coffre.ouvert .tdn-coffre-lueur{opacity:1;transform:scale(2.2);}

/* ---------- Révélation (grand écran) ---------- */
.tdn-revelation{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;
  padding:2rem 1.5rem;overflow:hidden;text-align:center;
  background:radial-gradient(ellipse at 50% 30%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);transition:background 1s;}
.tdn-revelation.tdn-grand{background:radial-gradient(ellipse at 50% 30%,#3d2a0f,var(--tdn-nuit) 75%);}
.tdn-rev-inner{position:relative;z-index:2;width:100%;max-width:56rem;}
.tdn-rev-titre{font-family:'Cormorant Garamond',serif;font-weight:700;text-transform:uppercase;letter-spacing:.06em;
  font-size:clamp(2.6rem,9vw,7rem);line-height:1;color:var(--tdn-or);margin:.6rem 0 1rem;
  text-shadow:0 0 50px rgba(229,192,123,.5);}
.tdn-rev-sous{font-size:clamp(1.2rem,3.5vw,2rem);color:var(--tdn-creme);margin-bottom:2rem;}
.tdn-rev-form{max-width:26rem;margin:0 auto 1.5rem;}
.tdn-rev-scene{display:flex;flex-direction:column;align-items:center;gap:2rem;}
.tdn-decompte{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(6rem,25vw,14rem);line-height:1;color:var(--tdn-or);
  animation:tdn-decompte 1s ease-out both;text-shadow:0 0 60px rgba(229,192,123,.6);}
@keyframes tdn-decompte{from{opacity:0;transform:scale(1.6)}30%{opacity:1;transform:scale(1)}to{opacity:.85}}
.tdn-rev-resultat{animation:tdn-apparait 1s ease both;}
.tdn-lot{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(2.2rem,8vw,6rem);line-height:1.05;
  color:var(--tdn-creme);margin:0 auto 1.5rem;max-width:20ch;padding:1.5rem;border-radius:26px;
  background:rgba(255,255,255,.06);border:2px solid rgba(229,192,123,.5);box-shadow:0 0 60px rgba(229,192,123,.25);}
.tdn-grand .tdn-lot{color:var(--tdn-or);border-color:var(--tdn-or);box-shadow:0 0 90px rgba(229,192,123,.5);}
.tdn-grand-tresor{display:inline-block;font-family:'DM Mono',monospace;text-transform:uppercase;letter-spacing:.3em;
  font-size:clamp(.9rem,2.5vw,1.4rem);color:var(--tdn-nuit);background:var(--tdn-or);padding:.6rem 1.4rem;border-radius:999px;
  animation:tdn-scintille 1.8s ease-in-out infinite;}
/* Carte du grand trésor révélée : photo de la carte à gauche, nom du lot à droite (empilés sur mobile). */
.tdn-lot.tdn-lot-visuel{display:flex;align-items:center;justify-content:center;gap:clamp(1.2rem,3.5vw,2.8rem);max-width:none;
  text-align:left;font-size:clamp(1.9rem,5vw,4.2rem);padding:clamp(1.3rem,2.6vw,2.2rem) clamp(1.3rem,3vw,2.6rem);}
.tdn-lot-photo{flex:0 0 auto;width:clamp(170px,34%,360px);height:auto;transform:rotate(-5deg);
  filter:drop-shadow(0 14px 26px rgba(0,0,0,.6));animation:tdn-carte-pose .9s cubic-bezier(.2,.8,.2,1) .3s both;}
@keyframes tdn-carte-pose{from{opacity:0;transform:rotate(-18deg) scale(.6)}to{opacity:1;transform:rotate(-5deg) scale(1)}}
@media (max-width:640px){
  .tdn-lot.tdn-lot-visuel{flex-direction:column;text-align:center;}
  .tdn-lot-photo{width:min(80%,300px);}
}
@media (prefers-reduced-motion:reduce){.tdn-lot-photo{animation:none;}}
/* Le bouton « Clé suivante » se détache du texte qui le précède. */
.tdn-rev-resultat > .tdn-btn{margin-top:2rem;}
.tdn-rev-partenaire{font-size:clamp(1rem,3vw,1.6rem);color:var(--tdn-creme);margin-bottom:1.4rem;}
.tdn-rev-partenaire b{color:var(--tdn-or);}
.tdn-particules{position:absolute;inset:0;pointer-events:none;overflow:hidden;}
.tdn-particules i{position:absolute;top:-10px;width:8px;height:8px;border-radius:2px;background:var(--tdn-or);
  animation:tdn-particule 3.2s ease-in both;}
.tdn-particules i:nth-child(odd){background:var(--tdn-creme);width:5px;height:5px;border-radius:50%;}
@keyframes tdn-particule{0%{transform:translateY(0) rotate(0);opacity:0}10%{opacity:1}100%{transform:translateY(110vh) rotate(540deg);opacity:0}}

/* ---------- Nav basse ---------- */
.tdn-nav{position:fixed;left:0;right:0;bottom:0;z-index:40;display:flex;
  background:rgba(8,20,48,.92);backdrop-filter:blur(12px);border-top:1px solid rgba(255,255,255,.1);
  padding-bottom:env(safe-area-inset-bottom);}
.tdn-nav a{flex:1;display:flex;flex-direction:column;align-items:center;gap:.15rem;padding:.6rem 0 .5rem;
  text-decoration:none;font-size:.7rem;font-weight:600;color:var(--tdn-muted);min-height:3.6rem;}
.tdn-nav a span{font-size:1.25rem;}
.tdn-nav a.on{color:var(--tdn-or);}

/* ---------- Accessibilité / mouvement réduit ---------- */
@media (prefers-reduced-motion:reduce){
  .tdn *,.tdn *::before,.tdn *::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important;}
  .tdn-neige{display:none;}
  .tdn-traineau{display:none;}
}

/* ---------- Page réservation (avant ouverture) ---------- */
.tdn-resa .tdn-hero{padding-bottom:12rem;}
.tdn-resa .tdn-hero::after{content:"";position:absolute;left:0;right:0;bottom:0;height:9rem;pointer-events:none;z-index:1;
  background:linear-gradient(to bottom,transparent,var(--tdn-nuit));}
.tdn-resa .tdn-village{z-index:0;}
.tdn-traineau-boucle{animation:tdn-traineau-boucle 14s ease-in-out 1.5s infinite;}
@keyframes tdn-traineau-boucle{0%{left:-340px;top:14%;opacity:0}6%{opacity:1}55%{opacity:1}62%{left:110%;top:5%;opacity:0}100%{left:110%;opacity:0}}
.tdn-bientot{margin-top:1.6rem;display:inline-flex;align-items:center;gap:.7rem;padding:.55rem 1.1rem .55rem .7rem;border:1px solid rgba(229,192,123,.45);border-radius:999px;background:rgba(8,20,48,.5);font-size:.9rem;}
.tdn-bientot b{display:inline-grid;place-items:center;width:1.7rem;height:1.7rem;border-radius:50%;background:var(--tdn-or);color:var(--tdn-nuit);font-size:.8rem;}
.tdn-tresor{text-align:center;padding-top:3rem;}
.tdn-coffre-fixe{position:relative;margin-bottom:1.4rem;}
.tdn-lumiere-locale{position:absolute;left:50%;top:45%;width:300px;height:300px;transform:translate(-50%,-50%);inset:auto;animation:none;
  background:radial-gradient(circle,rgba(229,192,123,.35),rgba(229,192,123,.08) 45%,transparent 68%);}
.tdn-coffre-fixe .tdn-coffre{position:relative;width:170px;height:125px;}
.tdn-montant{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(4.5rem,16vw,9rem);line-height:1.1;color:var(--tdn-creme);text-shadow:0 0 50px rgba(229,192,123,.55);margin:.2rem 0 .4rem;}
.tdn-montant-multi{font-size:clamp(3.8rem,14vw,9rem);white-space:nowrap;}
.tdn-hotte{width:min(100%,420px);height:auto;display:block;margin:0 auto .4rem;}
.tdn-quoi{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:1.5rem;color:var(--tdn-creme);margin-top:.4rem;}
.tdn-comment{margin:1.2rem auto 0;max-width:46ch;color:var(--tdn-muted);}
.tdn-autres{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:1.35rem;color:var(--tdn-or);margin-top:2rem;}
.tdn-raisons{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:1rem;}
.tdn-raison{padding:1.5rem 1.3rem;border:1px solid rgba(255,255,255,.12);border-radius:18px;background:rgba(255,255,255,.05);}
.tdn-raison h3{font-family:'Cormorant Garamond',serif;font-weight:600;font-size:1.55rem;color:var(--tdn-creme);margin:.4rem 0;}
.tdn-raison p{color:var(--tdn-muted);font-size:.95rem;line-height:1.5;}
.tdn-raison-or{border-color:rgba(229,192,123,.55);background:linear-gradient(135deg,rgba(229,192,123,.2),rgba(138,42,58,.22));}
.tdn-raison-or h3{color:var(--tdn-or);}
.tdn-raison-or p{color:var(--tdn-texte);}
.tdn-carte-resa{max-width:34rem;margin:0 auto;padding:2.2rem 1.6rem;border-color:rgba(229,192,123,.4);box-shadow:0 20px 60px rgba(0,0,0,.4);position:relative;text-align:center;}
.tdn-carte-resa h2{font-size:2.2rem;}
.tdn-sceau{position:absolute;top:-1.1rem;left:50%;transform:translateX(-50%);width:2.2rem;height:2.2rem;display:grid;place-items:center;border-radius:50%;background:var(--tdn-or);color:var(--tdn-nuit);}
.tdn-centre-txt{text-align:center;}
.tdn-tarifs{display:grid;grid-template-columns:1fr 1fr;gap:.8rem;margin:1.4rem 0;}
.tdn-tarifs div{padding:1rem;border-radius:14px;background:rgba(8,20,48,.6);border:1px solid rgba(255,255,255,.12);}
.tdn-tarifs span{display:block;font-size:.8rem;color:var(--tdn-muted);}
.tdn-tarifs b{font-family:'Cormorant Garamond',serif;font-size:2.2rem;color:var(--tdn-creme);line-height:1.1;}
.tdn-jauge-txt{font-size:.9rem;color:var(--tdn-muted);margin-bottom:.4rem;}
.tdn-jauge-txt b{color:var(--tdn-or);}
.tdn-reglement h2{font-family:'Cormorant Garamond',serif;font-weight:600;font-size:1.5rem;color:var(--tdn-or);margin:2rem 0 .6rem;}
.tdn-reglement p{line-height:1.65;margin-bottom:.8rem;color:var(--tdn-texte);}
.tdn-reglement b{color:var(--tdn-creme);}
.tdn-reglement-lots{margin:0 0 1rem 1.3rem;line-height:1.7;color:var(--tdn-texte);}

/* ---------- Tirage du grand trésor ---------- */
.tdn-tirage{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;padding:2rem 1.5rem;overflow:hidden;text-align:center;
  background:radial-gradient(ellipse at 50% 30%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);}
.tdn-tirage-inner{position:relative;z-index:2;width:100%;max-width:80rem;display:flex;flex-direction:column;align-items:center;}
.tdn-tirage-halo{position:absolute;inset:0;pointer-events:none;opacity:0;transition:opacity 1.5s;
  background:radial-gradient(circle at 50% 50%,rgba(229,192,123,.45) 0%,rgba(229,192,123,.1) 30%,transparent 60%);}
.tdn-tirage.fini .tdn-tirage-halo{opacity:1;}
.tdn-tirage-admin{position:fixed;top:1rem;right:1rem;z-index:5;display:flex;gap:.5rem;font-size:.75rem;color:var(--tdn-muted);}
.tdn-tirage-admin span,.tdn-tirage-admin a{padding:.4rem .7rem;border:1px solid rgba(255,255,255,.15);border-radius:999px;background:rgba(8,20,48,.6);text-decoration:none;}
.tdn-tirage-compteur{margin-top:1rem;font-family:'DM Mono',monospace;color:var(--tdn-muted);font-size:clamp(.9rem,1.6vw,1.2rem);}
.tdn-tirage-compteur b{color:var(--tdn-or);font-size:1.5em;}
.tdn-mur{margin:1.6rem auto 0;display:grid;grid-template-columns:repeat(auto-fill,minmax(88px,1fr));gap:.5rem;width:100%;max-height:42vh;overflow:auto;padding:.6rem;scrollbar-width:none;
  -webkit-mask-image:linear-gradient(to bottom,#000 75%,transparent);mask-image:linear-gradient(to bottom,#000 75%,transparent);}
.tdn-cle-tuile{font-family:'DM Mono',monospace;font-size:clamp(.9rem,1.5vw,1.2rem);padding:.55rem .3rem;border:1px solid rgba(229,192,123,.3);border-radius:8px;background:rgba(255,255,255,.04);color:var(--tdn-creme);transition:transform .15s,background .15s;}
.tdn-cle-tuile small{display:block;font-family:'Bricolage Grotesque',sans-serif;font-size:.7em;color:var(--tdn-muted);margin-top:.15rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.tdn-cle-tuile.on{background:var(--tdn-or);color:var(--tdn-nuit);transform:scale(1.15);box-shadow:0 0 30px rgba(229,192,123,.7);position:relative;z-index:2;}
.tdn-cle-tuile.on small{color:rgba(8,20,48,.7);}
.tdn-tambour{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(6rem,22vw,16rem);line-height:1;color:var(--tdn-creme);text-shadow:0 0 60px rgba(229,192,123,.6);letter-spacing:.05em;font-variant-numeric:tabular-nums;}
.tdn-tambour span{display:inline-block;min-width:.62em;}
.tdn-tirage-resultat{animation:tdn-apparait 1s ease both;}
.tdn-gagnant{margin:1.2rem 0 .6rem;padding:2rem 3rem;border-radius:26px;border:2px solid var(--tdn-or);background:rgba(255,255,255,.06);box-shadow:0 0 90px rgba(229,192,123,.45);}
.tdn-gagnant-num{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(3rem,12vw,9rem);line-height:1;color:var(--tdn-creme);text-shadow:0 0 50px rgba(229,192,123,.6);}
.tdn-gagnant-nom{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:clamp(1.6rem,4vw,3rem);color:var(--tdn-or);margin-top:.3rem;}
.tdn-gagnant-famille{color:var(--tdn-muted);font-size:clamp(1rem,2vw,1.4rem);}


/* ---------- Tirage : plusieurs lots, un gagnant dévoilé après l'autre ---------- */
.tdn-tirage-etape{font-family:'DM Mono',monospace;text-transform:uppercase;letter-spacing:.2em;font-size:clamp(.8rem,1.5vw,1.15rem);
  color:var(--tdn-nuit);background:var(--tdn-or);padding:.45rem 1.1rem;border-radius:999px;margin-bottom:1.2rem;}
.tdn-cle-tuile.tiree{border-color:var(--tdn-or);background:rgba(229,192,123,.16);color:var(--tdn-or);opacity:.6;}
.tdn-gagnant-lot{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:clamp(1.3rem,3vw,2.2rem);color:var(--tdn-creme);margin-top:.4rem;}
.tdn-gagnant-rang{font-family:'DM Mono',monospace;text-transform:uppercase;letter-spacing:.18em;font-size:clamp(.7rem,1.1vw,.9rem);color:var(--tdn-or);margin-bottom:.5rem;}
.tdn-podium{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:1.2rem;width:100%;max-width:72rem;margin:1.4rem 0 1.6rem;}
.tdn-podium .tdn-gagnant{margin:0;padding:1.5rem 1rem;box-shadow:0 0 60px rgba(229,192,123,.35);}
.tdn-podium .tdn-gagnant-num{font-size:clamp(2.2rem,5vw,4.6rem);}
.tdn-podium .tdn-gagnant-nom{font-size:clamp(1.4rem,2.6vw,2.3rem);}
.tdn-podium .tdn-gagnant-famille{font-size:clamp(.9rem,1.4vw,1.15rem);}
.tdn-lot.tdn-lot-recap{font-size:clamp(1.4rem,3.2vw,2.6rem);max-width:none;padding:1rem 1.6rem;margin-bottom:1rem;color:var(--tdn-or);border-color:var(--tdn-or);}
.tdn-podium ~ .tdn-rev-sous{margin-bottom:1.2rem;}
/* Présentation et récapitulatif peuvent dépasser l'écran (portable, mobile) : on les laisse défiler
   au lieu de les rogner, pour que les boutons restent toujours atteignables. */
.tdn-tirage.defile{height:100svh;min-height:0;overflow-y:auto;align-items:flex-start;}
.tdn-tirage.defile .tdn-tirage-inner{margin:auto 0;}
@media (max-width:700px){.tdn-tirage.defile{padding-top:4.5rem;}}

/* =========================================================
   MON AVENTURE — carte du parcours (.tdn-map)
   Un chemin qui serpente dans le village de nuit, une étape par mission, le lutin sur l'étape en cours.
   Le dessin (CarteParcours.tsx) est un SVG de 360 × 800 : il suit la largeur de l'écran et la page défile.
   En-tête et fiche de mission restent fixes par-dessus. Animations sur transform / opacity uniquement.
   ========================================================= */
.tdn-map-page{min-height:100svh;}
.tdn-map{position:relative;width:100%;max-width:30rem;margin:0 auto;aspect-ratio:360/800;overflow:hidden;background:var(--tdn-nuit);}
.tdn-map-svg{position:absolute;inset:0;width:100%;height:100%;display:block;}
.tdn-map-traineau{position:absolute;left:0;top:11.5%;width:37%;height:auto;overflow:visible;pointer-events:none;
  color:rgba(251,247,239,.72);animation:tdn-map-traineau 28s linear infinite;}
@keyframes tdn-map-traineau{0%{transform:translate(-115%,70%)}38%,100%{transform:translate(295%,-45%)}}
.tdn-map-repere{position:absolute;width:1px;height:1px;pointer-events:none;}
.tdn-map-lien{position:absolute;width:13%;aspect-ratio:1;border-radius:50%;transform:translate(-50%,-50%);-webkit-tap-highlight-color:transparent;}
.tdn-map-lien:focus-visible{outline:3px solid var(--tdn-or);outline-offset:3px;}

/* En-tête, fiche et message de réussite : fixes, alignés sur la largeur de la carte. */
.tdn-map-entete,.tdn-map-bas,.tdn-map-bravo{position:fixed;left:50%;transform:translateX(-50%);width:min(100%,30rem);z-index:30;}
.tdn-map-entete{top:0;padding:calc(1.1rem + env(safe-area-inset-top)) 1rem 1.9rem;pointer-events:none;
  background:linear-gradient(#040b22 0%,rgba(4,11,34,.93) 52%,rgba(4,11,34,.62) 78%,rgba(4,11,34,0));}
.tdn-map-entete > *{pointer-events:auto;}
.tdn-map-ligne{display:flex;align-items:center;justify-content:space-between;gap:.8rem;}
.tdn .tdn-map-bonjour{margin:0;font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:1.75rem;line-height:1;color:var(--tdn-creme);}
.tdn-map-score{display:inline-flex;align-items:center;gap:.4rem;padding:.42rem .8rem;border-radius:999px;white-space:nowrap;
  background:rgba(8,20,48,.72);border:1px solid rgba(229,192,123,.6);color:#f6e3b8;font-weight:800;font-size:.875rem;font-variant-numeric:tabular-nums;}
.tdn-map-score b{color:var(--tdn-or);font-weight:400;}
.tdn-map-entete .tdn-chips{margin-top:.75rem;gap:.4rem;}
.tdn-map-entete .tdn-chips button{min-height:2.25rem;padding:0 .9rem;font-size:.8rem;border-width:1px;background:rgba(8,20,48,.55);}
.tdn-map-entete .tdn-chips button.on{background:var(--tdn-or);}

.tdn-map-bas{bottom:calc(3.6rem + env(safe-area-inset-bottom));padding:0 .75rem .7rem;pointer-events:none;}
.tdn-map-fiche{pointer-events:auto;display:flex;align-items:center;justify-content:space-between;gap:.7rem;min-height:4.9rem;
  padding:.7rem .75rem .7rem 1.05rem;border-radius:1.4rem;background:rgba(7,17,44,.92);border:1px solid rgba(229,192,123,.42);
  box-shadow:0 12px 30px rgba(2,6,20,.45);backdrop-filter:blur(8px);}
.tdn-map-fiche p{margin:0;}
.tdn-map-fnum{font-size:.75rem;font-weight:800;color:var(--tdn-or);}
.tdn .tdn-map-ftitre{margin:0;padding:.1rem 0 .15rem;font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:1.3rem;line-height:1.1;color:var(--tdn-creme);
  display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}
.tdn-map-flieu{font-size:.75rem;color:var(--tdn-muted);}
.tdn .tdn-map-jouer{flex:none;display:inline-flex;align-items:center;justify-content:center;min-height:2.9rem;padding:0 1.2rem;border-radius:999px;
  text-decoration:none;white-space:nowrap;background:linear-gradient(135deg,#ecd08f,var(--tdn-or-2));color:var(--tdn-nuit);font-weight:800;font-size:.92rem;
  box-shadow:0 6px 18px rgba(229,192,123,.35);}
.tdn .tdn-map-jouer:active{transform:scale(.97);}

.tdn-map-bravo{top:calc(6.2rem + env(safe-area-inset-top));margin:0;padding:.9rem 0 1.1rem;text-align:center;pointer-events:none;opacity:0;
  font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-style:italic;font-size:2rem;color:#f8e4b2;
  text-shadow:0 0 22px rgba(229,192,123,.75),0 2px 0 var(--tdn-nuit);
  background:radial-gradient(ellipse 62% 70% at 50% 50%,rgba(4,11,34,.86),rgba(4,11,34,0) 72%);
  animation:tdn-map-bravo 3.6s ease-out both;}
@keyframes tdn-map-bravo{0%,12%{opacity:0;transform:translate(-50%,10px) scale(.94)}20%,72%{opacity:1;transform:translate(-50%,0)}86%,100%{opacity:0;transform:translate(-50%,-8px)}}

/* ----- vie du village (boucles douces) ----- */
.tdn-map .m-num{font:800 14px 'Bricolage Grotesque',system-ui,sans-serif;}
.tdn-map .m-or{fill:none;stroke:#f2d089;stroke-width:5;stroke-linecap:round;filter:drop-shadow(0 0 5px rgba(242,208,137,.8));}
.tdn-map .m-etoile{animation:tdn-map-etoile 4s ease-in-out infinite alternate;}
.tdn-map .m-fen{animation:tdn-map-fen 3.2s ease-in-out infinite alternate;}
.tdn-map .m-guir{animation:tdn-map-guir 1.7s ease-in-out infinite alternate;}
.tdn-map .m-fumee{opacity:0;transform-box:fill-box;transform-origin:center;animation:tdn-map-fumee 4.5s ease-out infinite;}
.tdn-map .m-halo{transform-box:fill-box;transform-origin:center;animation:tdn-map-halo 3.4s ease-in-out infinite alternate;}
.tdn-map .m-lanterne{animation-duration:1.9s;}
.tdn-map .m-d1{animation-delay:0s;}
.tdn-map .m-d2{animation-delay:-1.1s;}
.tdn-map .m-d3{animation-delay:-2.3s;}
.tdn-map .m-fumee.m-d2{animation-delay:-1.5s;}
.tdn-map .m-fumee.m-d3{animation-delay:-3s;}
.tdn-map .m-saut{animation:tdn-map-saut 1.1s ease-in-out infinite alternate;}
.tdn-map .m-fete .m-saut{animation:tdn-map-fete .5s ease-in-out infinite alternate;}
.tdn-map .m-onde{transform-box:fill-box;transform-origin:center;animation:tdn-map-onde 1.9s ease-out infinite;}
.tdn-map .m-onde.m-d2{animation-delay:.95s;}
.tdn-map .m-rayons{transform-origin:180px 198px;animation:tdn-map-rayons 5s ease-in-out infinite alternate;}
.tdn-map .m-scint{transform-box:fill-box;transform-origin:center;animation:tdn-map-scint 1.6s ease-in-out infinite alternate;}
.tdn-map .m-cle{animation:tdn-map-cle 1.6s ease-in-out infinite alternate;filter:drop-shadow(0 0 6px rgba(255,226,154,.9));}
.tdn-map .m-flocon{animation:tdn-map-chute linear infinite;}
@keyframes tdn-map-etoile{from{opacity:.35}to{opacity:1}}
@keyframes tdn-map-fen{from{opacity:.7}to{opacity:1}}
@keyframes tdn-map-guir{from{opacity:.3}to{opacity:1}}
@keyframes tdn-map-fumee{0%{opacity:0;transform:translate(0,0) scale(.6)}18%{opacity:.42}100%{opacity:0;transform:translate(7px,-24px) scale(1.7)}}
@keyframes tdn-map-halo{from{opacity:.65;transform:scale(.92)}to{opacity:1;transform:scale(1.07)}}
@keyframes tdn-map-saut{from{transform:translateY(0)}to{transform:translateY(-3px)}}
@keyframes tdn-map-fete{from{transform:translateY(0)}to{transform:translateY(-10px)}}
@keyframes tdn-map-onde{from{opacity:.95;transform:scale(1)}to{opacity:0;transform:scale(1.8)}}
@keyframes tdn-map-rayons{from{opacity:.6;transform:rotate(-5deg)}to{opacity:1;transform:rotate(5deg)}}
@keyframes tdn-map-scint{from{opacity:.25;transform:scale(.5)}to{opacity:1;transform:scale(1.15)}}
@keyframes tdn-map-cle{from{transform:translateY(0)}to{transform:translateY(-5px)}}
@keyframes tdn-map-chute{to{transform:translate(18px,830px)}}

/* ----- « mission accomplie » : séquence jouée une fois à l'arrivée sur la carte (?bravo=N) -----
   L'étape passe à l'or, le bâtiment associé s'allume, le chemin doré avance et le lutin saute à l'étape suivante.
   L'état de repos de chaque élément est l'état final : sans animation, la carte est simplement à jour. */
.tdn-map .m-b-avant{opacity:0;animation:tdn-map-b-avant 3.6s linear both;}
.tdn-map .m-b-fait{animation:tdn-map-b-fait 3.6s linear both;}
.tdn-map .m-b-allume{animation:tdn-map-b-allume 3.6s linear both;}
.tdn-map .m-b-suivante{animation:tdn-map-b-suivante 3.6s linear both;}
.tdn-map .m-b-eclat{opacity:0;transform-box:fill-box;transform-origin:center;animation:tdn-map-b-eclat 3.6s ease-out both;}
.tdn-map .m-b-trace{animation:tdn-map-b-trace 3.6s ease-in-out both;}
.tdn-map .m-b-marche{animation:tdn-map-b-marche 3.6s ease-in-out both;}
@keyframes tdn-map-b-avant{0%,14%{opacity:1}22%,100%{opacity:0}}
@keyframes tdn-map-b-fait{0%,14%{opacity:0}22%,100%{opacity:1}}
@keyframes tdn-map-b-allume{0%,22%{opacity:0}46%,100%{opacity:1}}
@keyframes tdn-map-b-suivante{0%,78%{opacity:0}88%,100%{opacity:1}}
@keyframes tdn-map-b-eclat{0%,14%{opacity:0;transform:translateY(-6px) scale(.3)}19%{opacity:1}38%,100%{opacity:0;transform:translateY(-38px) scale(1.1)}}
@keyframes tdn-map-b-trace{0%,32%{stroke-dasharray:var(--f0) 1}78%,100%{stroke-dasharray:var(--f1) 1}}
@keyframes tdn-map-b-marche{
  0%,32%{transform:translate(var(--dx),var(--dy))}
  40%{transform:translate(calc(var(--dx)*.83),calc(var(--dy)*.83 - 9px))}
  47%{transform:translate(calc(var(--dx)*.67),calc(var(--dy)*.67))}
  55%{transform:translate(calc(var(--dx)*.5),calc(var(--dy)*.5 - 9px))}
  63%{transform:translate(calc(var(--dx)*.33),calc(var(--dy)*.33))}
  70%{transform:translate(calc(var(--dx)*.17),calc(var(--dy)*.17 - 9px))}
  78%,100%{transform:translate(0,0)}
}
@media (prefers-reduced-motion:reduce){.tdn-map-traineau,.tdn-map .m-flocon{display:none;}}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-de-noel/tresors.css"

git add -A && git commit -m "Trésors de Noël : Mon aventure en carte du village (parcours, lutin, animation mission accomplie)" && git push
vercel --prod
