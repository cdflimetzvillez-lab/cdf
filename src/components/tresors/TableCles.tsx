'use client';
import { useTransition } from 'react';
import { majCle, numeroCle } from '@/app/tresors-actions';
import type { Lot } from '@/lib/tresors/types';

type Ligne = { id: string; numero: number; code: string; prenom: string; famille: string; lot_id: string | null; lot: string; revelee: boolean };

export default function TableCles({ lignes, lots }: { lignes: Ligne[]; lots: Lot[] }) {
  const [pending, start] = useTransition();

  function exporter() {
    const rows = [['numero', 'code', 'prenom', 'famille', 'lot', 'revelee'], ...lignes.map((l) => [numeroCle(l.numero), l.code, l.prenom, l.famille, l.lot, l.revelee ? 'oui' : 'non'])];
    const csv = rows.map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(';')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })); a.download = 'cles-tresors-de-noel.csv'; a.click();
  }

  return (
    <div className="panel" style={{ opacity: pending ? .7 : 1 }}>
      <div style={{ textAlign: 'right', marginBottom: '1rem' }}><button className="btn btn-k btn-sm" onClick={exporter}>Exporter les clés</button></div>
      <table className="tbl">
        <thead><tr><th>N°</th><th>Code</th><th>Participant</th><th>Famille</th><th>Lot</th><th>Révélée</th></tr></thead>
        <tbody>
          {lignes.map((l) => (
            <tr key={l.id}>
              <td className="mono">{numeroCle(l.numero)}</td><td className="mono">{l.code}</td><td><b>{l.prenom}</b></td><td>{l.famille}</td>
              <td>
                <select value={l.lot_id ?? ''} onChange={(e) => start(() => majCle(l.id, { lot_id: e.target.value || null }))} style={{ padding: '.4rem', border: '2px solid var(--noir)' }}>
                  <option value="">Tirage au sort à la révélation</option>
                  {lots.map((lot) => <option key={lot.id} value={lot.id}>{lot.grand ? '★ ' : ''}{lot.nom}</option>)}
                </select>
              </td>
              <td>
                <button className={`pill ${l.revelee ? 'done' : 'off'}`} style={{ cursor: 'pointer' }} onClick={() => start(() => majCle(l.id, { revelee: !l.revelee }))}>
                  {l.revelee ? 'oui' : 'non'}
                </button>
              </td>
            </tr>
          ))}
          {lignes.length === 0 && <tr><td colSpan={6}>Aucune clé générée pour le moment.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
