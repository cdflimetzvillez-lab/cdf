import type { Cle } from '@/lib/tresors/types';
import { numeroCle } from '@/lib/tresors/types';

/** QR code purement décoratif (motif pseudo-aléatoire déterministe). */
function FauxQR({ graine }: { graine: string }) {
  const n = 17;
  let h = 0;
  for (const c of graine) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  const cases: boolean[] = [];
  for (let i = 0; i < n * n; i++) { h = (h * 1103515245 + 12345) >>> 0; cases.push(((h >> 16) & 1) === 1); }
  const coin = (x: number, y: number) => (
    <g key={`${x}${y}`}>
      <rect x={x} y={y} width="7" height="7" fill="currentColor" />
      <rect x={x + 1} y={y + 1} width="5" height="5" fill="var(--tdn-creme)" />
      <rect x={x + 2} y={y + 2} width="3" height="3" fill="currentColor" />
    </g>
  );
  return (
    <svg className="tdn-qr" viewBox={`0 0 ${n} ${n}`} shapeRendering="crispEdges" aria-hidden="true">
      {cases.map((b, i) => {
        const x = i % n, y = Math.floor(i / n);
        const dansCoin = (x < 8 && y < 8) || (x > n - 9 && y < 8) || (x < 8 && y > n - 9);
        return b && !dansCoin ? <rect key={i} x={x} y={y} width="1" height="1" fill="currentColor" /> : null;
      })}
      {coin(0, 0)}{coin(n - 7, 0)}{coin(0, n - 7)}
    </svg>
  );
}

export default function CarteCle({ cle, prenom, marche, grande = false }: { cle: Cle; prenom: string; marche: string; grande?: boolean }) {
  return (
    <div className={`tdn-cle${grande ? ' tdn-cle-grande' : ''}`}>
      <div className="tdn-cle-brillance" aria-hidden="true" />
      <div className="tdn-cle-haut">
        <span className="tdn-sur">Clé virtuelle</span>
        <span className={`tdn-pastille ${cle.revelee_le ? 'tdn-pastille-ok' : ''}`}>{cle.revelee_le ? 'Révélée' : 'Non révélée'}</span>
      </div>
      <svg className="tdn-cle-icone" viewBox="0 0 64 32" aria-hidden="true">
        <circle cx="13" cy="16" r="9" fill="none" stroke="currentColor" strokeWidth="3.5" />
        <path d="M22 16 H58 M50 16 v8 M42 16 v6" stroke="currentColor" strokeWidth="3.5" strokeLinecap="round" fill="none" />
      </svg>
      <div className="tdn-cle-num">CLÉ N° {numeroCle(cle.numero)}</div>
      <div className="tdn-sur">Code secret</div>
      <div className="tdn-cle-code">{cle.code}</div>
      <div className="tdn-cle-bas">
        <div>
          <div className="tdn-sur">Participant</div>
          <b>{prenom}</b>
          <div className="tdn-sur" style={{ marginTop: '.6rem' }}>Événement</div>
          <b>Marché de Noël</b>
          <small>{marche}</small>
        </div>
        <FauxQR graine={cle.numero + cle.code} />
      </div>
    </div>
  );
}
