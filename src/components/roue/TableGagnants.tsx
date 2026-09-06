'use client';
import { useTransition } from 'react';
import { marquerRetire } from '@/app/roue-actions';
import type { ParticipationRoue } from '@/lib/roue/types';

const fmt = (iso: string) => new Intl.DateTimeFormat('fr-FR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'Europe/Paris' }).format(new Date(iso));

export default function TableGagnants({ lignes }: { lignes: ParticipationRoue[] }) {
  const [pending, start] = useTransition();
  function exporter() {
    const rows = [['date', 'code', 'lot', 'prenom', 'email', 'telephone', 'retire'],
      ...lignes.map((l) => [fmt(l.created_at), l.code ?? '', l.roue_lots?.nom ?? '', l.prenom ?? '', l.email ?? '', l.telephone ?? '', l.retire_le ? 'oui' : 'non'])];
    const csv = rows.map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(';')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })); a.download = 'gagnants-roue.csv'; a.click();
  }
  return (
    <div className="panel" style={{ opacity: pending ? .7 : 1 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <h2 style={{ margin: 0 }}>Gagnants ({lignes.length})</h2>
        <button className="btn btn-k btn-sm" onClick={exporter}>Exporter CSV</button>
      </div>
      <table className="tbl">
        <thead><tr><th>Date</th><th>Code</th><th>Lot</th><th>Gagnant</th><th>Contact</th><th>Retiré</th></tr></thead>
        <tbody>
          {lignes.map((l) => (
            <tr key={l.id}>
              <td>{fmt(l.created_at)}</td><td className="mono">{l.code}</td><td>{l.roue_lots?.nom ?? '—'}</td>
              <td>{l.prenom ?? <span style={{ color: '#6b6560' }}>non renseigné</span>}</td>
              <td style={{ fontSize: '.8rem' }}>{l.email}<br />{l.telephone}</td>
              <td><button className={`pill ${l.retire_le ? 'done' : 'off'}`} style={{ cursor: 'pointer' }} onClick={() => start(() => marquerRetire(l.id, !l.retire_le))}>{l.retire_le ? 'oui' : 'non'}</button></td>
            </tr>
          ))}
          {lignes.length === 0 && <tr><td colSpan={6}>Aucun gagnant pour le moment.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
