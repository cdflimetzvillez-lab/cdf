'use client';
import { useState, useTransition } from 'react';
import { marquerPaye, supprimerParticipantAdmin, numeroCle } from '@/app/tresors-actions';

type Ligne = { id: string; prenom: string; categorie: string; paye: boolean; responsable: string; email: string; telephone: string; progression: number; cle: number | null; statut: string };

export default function TableParticipants({ lignes, nbMissions }: { lignes: Ligne[]; nbMissions: number }) {
  const [q, setQ] = useState('');
  const [, start] = useTransition();
  const f = q.trim().toLowerCase();
  const vis = lignes.filter((l) => !f || `${l.prenom} ${l.responsable} ${l.email}`.toLowerCase().includes(f));
  const pill = (s: string) => (s === 'révélé' || s === 'terminé' ? 'done' : s === 'en cours' ? 'new' : 'off');

  function exporter() {
    const rows = [['prenom', 'categorie', 'paye', 'responsable', 'email', 'telephone', 'progression', 'cle', 'statut'],
      ...lignes.map((l) => [l.prenom, l.categorie, l.paye ? 'oui' : 'non', l.responsable, l.email, l.telephone, `${l.progression}/${nbMissions}`, l.cle ? numeroCle(l.cle) : '', l.statut])];
    const csv = rows.map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(';')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })); a.download = 'participants-tresors.csv'; a.click();
  }

  return (
    <div className="panel">
      <div style={{ display: 'flex', gap: '.8rem', justifyContent: 'space-between', flexWrap: 'wrap', marginBottom: '1rem' }}>
        <input placeholder="Rechercher un prénom, un responsable, un e-mail…" value={q} onChange={(e) => setQ(e.target.value)} style={{ flex: 1, minWidth: 240, padding: '.6rem .8rem', border: '2px solid var(--noir)' }} />
        <button className="btn btn-k btn-sm" onClick={exporter}>Exporter CSV</button>
      </div>
      <table className="tbl">
        <thead><tr><th>Prénom</th><th>Cat.</th><th>Responsable</th><th>Contact</th><th>Progression</th><th>Clé</th><th>Statut</th><th></th></tr></thead>
        <tbody>
          {vis.map((l) => (
            <tr key={l.id}>
              <td><b>{l.prenom}</b></td><td>{l.categorie}</td><td>{l.responsable}</td>
              <td style={{ fontSize: '.8rem' }}>{l.email}<br />{l.telephone}</td>
              <td>{l.progression} / {nbMissions}</td><td className="mono">{l.cle ? numeroCle(l.cle) : '—'}</td>
              <td><span className={`pill ${pill(l.statut)}`}>{l.statut}</span></td>
              <td style={{ whiteSpace: 'nowrap' }}>
                <button className="btn btn-w btn-sm" onClick={() => start(() => marquerPaye(l.id, !l.paye))}>{l.paye ? 'Marquer non payé' : 'Marquer payé'}</button>{' '}
                <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer ${l.prenom} ?`)) start(() => supprimerParticipantAdmin(l.id)); }}>✕</button>
              </td>
            </tr>
          ))}
          {vis.length === 0 && <tr><td colSpan={8}>Aucun participant.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
