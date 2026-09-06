'use client';
import { useActionState, useState, useTransition } from 'react';
import { enregistrerLotRoue, supprimerLotRoue, type EtatRoue } from '@/app/roue-actions';
import type { LotRoue } from '@/lib/roue/types';

function FormLot({ lot, onFin }: { lot: LotRoue | null; onFin?: () => void }) {
  const [etat, action, pending] = useActionState<EtatRoue, FormData>(async (p, fd) => { const r = await enregistrerLotRoue(p, fd); if (r?.ok) onFin?.(); return r; }, null);
  return (
    <form action={action} style={{ border: '2px solid var(--noir)', padding: '1rem', marginBottom: '1rem', background: '#faf7f2' }}>
      <input type="hidden" name="id" value={lot?.id ?? ''} />
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="row2">
        <div className="field"><label>Nom</label><input name="nom" defaultValue={lot?.nom ?? ''} required /></div>
        <div className="field"><label>Description</label><input name="description" defaultValue={lot?.description ?? ''} /></div>
      </div>
      <div className="row3">
        <div className="field"><label>Stock</label><input name="stock" type="number" min={0} defaultValue={lot?.stock ?? 1} /></div>
        <div className="field"><label>Poids (probabilité relative)</label><input name="poids" type="number" min={0} defaultValue={lot?.poids ?? 1} /></div>
        <div className="field"><label>Position</label><input name="position" type="number" defaultValue={lot?.position ?? 0} /></div>
      </div>
      <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="actif" defaultChecked={lot?.actif ?? true} style={{ width: 'auto' }} /> Actif (peut être gagné)</label>
      <div style={{ display: 'flex', gap: '.5rem' }}>
        <button className="btn btn-k btn-sm" disabled={pending}>{lot ? 'Enregistrer' : '+ Ajouter le lot'}</button>
        {onFin && <button type="button" className="btn btn-w btn-sm" onClick={onFin}>Annuler</button>}
      </div>
    </form>
  );
}

export default function GestionLotsRoue({ lots, pris }: { lots: LotRoue[]; pris: Record<string, number> }) {
  const [edit, setEdit] = useState<string | null>(null);
  const [, start] = useTransition();
  return (
    <div className="panel">
      <h2>Lots</h2>
      <table className="tbl">
        <thead><tr><th>Nom</th><th>Description</th><th>Stock</th><th>Gagnés</th><th>Restants</th><th>Poids</th><th>Actif</th><th></th></tr></thead>
        <tbody>
          {lots.map((l) => (
            <tr key={l.id}>
              {edit === l.id ? <td colSpan={8}><FormLot lot={l} onFin={() => setEdit(null)} /></td> : (<>
                <td><b>{l.nom}</b></td><td>{l.description}</td><td>{l.stock}</td><td>{pris[l.id] ?? 0}</td>
                <td><b>{Math.max(l.stock - (pris[l.id] ?? 0), 0)}</b></td><td>{l.poids}</td>
                <td><span className={`pill ${l.actif ? 'on' : 'off'}`}>{l.actif ? 'oui' : 'non'}</span></td>
                <td style={{ whiteSpace: 'nowrap' }}>
                  <button className="btn btn-y btn-sm" onClick={() => setEdit(l.id)}>Modifier</button>{' '}
                  <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer « ${l.nom} » ?`)) start(() => supprimerLotRoue(l.id)); }}>✕</button>
                </td>
              </>)}
            </tr>
          ))}
          {lots.length === 0 && <tr><td colSpan={8}>Aucun lot : tous les tours seront perdants.</td></tr>}
        </tbody>
      </table>
      <h3 style={{ margin: '1.4rem 0 .6rem', fontSize: '1rem' }}>Ajouter un lot</h3>
      <FormLot lot={null} />
    </div>
  );
}
