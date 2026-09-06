'use client';
import { useActionState, useState, useTransition } from 'react';
import { enregistrerLot, enregistrerPartenaire, supprimerLot, supprimerPartenaire, type Etat } from '@/app/tresors-actions';
import type { Lot, Partenaire } from '@/lib/tresors/types';

type Props = { lots: Lot[]; partenaires: Partenaire[]; compte: Record<string, { attribues: number; reveles: number }> };

function FormLot({ lot, partenaires, onFin }: { lot: Lot | null; partenaires: Partenaire[]; onFin?: () => void }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(async (p, fd) => { const r = await enregistrerLot(p, fd); if (r?.ok) onFin?.(); return r; }, null);
  return (
    <form action={action} style={{ border: '2px solid var(--noir)', padding: '1rem', marginBottom: '1rem', background: '#faf7f2' }}>
      <input type="hidden" name="id" value={lot?.id ?? ''} />
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="row3">
        <div className="field"><label>Nom</label><input name="nom" defaultValue={lot?.nom ?? ''} required /></div>
        <div className="field"><label>Valeur affichée</label><input name="valeur" defaultValue={lot?.valeur ?? ''} placeholder="24 €" /></div>
        <div className="field"><label>Partenaire</label>
          <select name="partenaire_id" defaultValue={lot?.partenaire_id ?? ''}><option value="">—</option>{partenaires.map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}</select></div>
      </div>
      <div className="row3">
        <div className="field"><label>Stock</label><input name="stock" type="number" min={0} defaultValue={lot?.stock ?? 1} /></div>
        <div className="field"><label>Position</label><input name="position" type="number" defaultValue={lot?.position ?? 0} /></div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center', marginTop: '1.4rem' }}>
          <input type="checkbox" name="grand" defaultChecked={lot?.grand ?? false} style={{ width: 'auto' }} /> Grand trésor (attribution manuelle)
        </label>
      </div>
      <div style={{ display: 'flex', gap: '.5rem' }}>
        <button className="btn btn-k btn-sm" disabled={pending}>{lot ? 'Enregistrer' : '+ Ajouter le lot'}</button>
        {onFin && <button type="button" className="btn btn-w btn-sm" onClick={onFin}>Annuler</button>}
      </div>
    </form>
  );
}

function FormPartenaire({ p, onFin }: { p: Partenaire | null; onFin?: () => void }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(async (prev, fd) => { const r = await enregistrerPartenaire(prev, fd); if (r?.ok) onFin?.(); return r; }, null);
  return (
    <form action={action} style={{ border: '2px solid var(--noir)', padding: '1rem', marginBottom: '1rem', background: '#faf7f2' }}>
      <input type="hidden" name="id" value={p?.id ?? ''} />
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="row2">
        <div className="field"><label>Nom</label><input name="nom" defaultValue={p?.nom ?? ''} required /></div>
        <div className="field"><label>Type</label><input name="type" defaultValue={p?.type ?? ''} placeholder="Commerce, Restaurant…" /></div>
      </div>
      <div style={{ display: 'flex', gap: '.5rem' }}>
        <button className="btn btn-k btn-sm" disabled={pending}>{p ? 'Enregistrer' : '+ Ajouter le partenaire'}</button>
        {onFin && <button type="button" className="btn btn-w btn-sm" onClick={onFin}>Annuler</button>}
      </div>
    </form>
  );
}

export default function GestionLots({ lots, partenaires, compte }: Props) {
  const [editLot, setEditLot] = useState<string | null>(null);
  const [editPart, setEditPart] = useState<string | null>(null);
  const [, start] = useTransition();

  return (
    <>
      <div className="panel">
        <h2>Lots</h2>
        <table className="tbl">
          <thead><tr><th>Nom</th><th>Valeur</th><th>Partenaire</th><th>Stock</th><th>Attribué</th><th>Révélé</th><th></th></tr></thead>
          <tbody>
            {lots.map((l) => (
              <tr key={l.id}>
                <td colSpan={editLot === l.id ? 7 : 1}>
                  {editLot === l.id ? <FormLot lot={l} partenaires={partenaires} onFin={() => setEditLot(null)} /> : <>{l.grand && <span className="pill new" style={{ marginRight: '.5rem' }}>Grand</span>}<b>{l.nom}</b></>}
                </td>
                {editLot !== l.id && (<>
                  <td>{l.valeur}</td><td>{l.tdn_partenaires?.nom ?? '—'}</td><td>{l.stock}</td>
                  <td>{compte[l.id]?.attribues ?? 0}</td><td>{compte[l.id]?.reveles ?? 0}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    <button className="btn btn-y btn-sm" onClick={() => setEditLot(l.id)}>Modifier</button>{' '}
                    <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer « ${l.nom} » ?`)) start(() => supprimerLot(l.id)); }}>✕</button>
                  </td>
                </>)}
              </tr>
            ))}
          </tbody>
        </table>
        <h3 style={{ margin: '1.4rem 0 .6rem', fontSize: '1rem' }}>Ajouter un lot</h3>
        <FormLot lot={null} partenaires={partenaires} />
      </div>

      <div className="panel">
        <h2>Partenaires</h2>
        <table className="tbl">
          <thead><tr><th>Nom</th><th>Type</th><th>Lots</th><th></th></tr></thead>
          <tbody>
            {partenaires.map((p) => (
              <tr key={p.id}>
                {editPart === p.id ? <td colSpan={4}><FormPartenaire p={p} onFin={() => setEditPart(null)} /></td> : (<>
                  <td><b>{p.nom}</b></td><td>{p.type}</td><td>{lots.filter((l) => l.partenaire_id === p.id).length}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    <button className="btn btn-y btn-sm" onClick={() => setEditPart(p.id)}>Modifier</button>{' '}
                    <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer « ${p.nom} » ?`)) start(() => supprimerPartenaire(p.id)); }}>✕</button>
                  </td>
                </>)}
              </tr>
            ))}
          </tbody>
        </table>
        <h3 style={{ margin: '1.4rem 0 .6rem', fontSize: '1rem' }}>Ajouter un partenaire</h3>
        <FormPartenaire p={null} />
      </div>
    </>
  );
}
