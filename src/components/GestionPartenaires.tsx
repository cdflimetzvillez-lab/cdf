'use client';
import { useActionState, useState, useTransition } from 'react';
import ChampImage from '@/components/ChampImage';
import { enregistrerPartenaire, supprimerPartenaire } from '@/app/actions';
import type { Partenaire } from '@/lib/types';

type Etat = { ok?: string; erreur?: string } | null;

function Form({ p, onFin }: { p: Partenaire | null; onFin?: () => void }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(async (prev, fd) => { const r = await enregistrerPartenaire(prev, fd); if (r?.ok) onFin?.(); return r; }, null);
  return (
    <form action={action} style={{ border: '2px solid var(--noir)', padding: '1rem', marginBottom: '1rem', background: '#faf7f2' }}>
      <input type="hidden" name="id" value={p?.id ?? ''} />
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="row2">
        <div>
          <div className="field"><label>Nom</label><input name="nom" defaultValue={p?.nom ?? ''} required /></div>
          <div className="field"><label>Site web (optionnel)</label><input name="site_url" type="url" placeholder="https://…" defaultValue={p?.site_url ?? ''} /></div>
          <div className="row2">
            <div className="field"><label>Position</label><input name="position" type="number" defaultValue={p?.position ?? 0} /></div>
            <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center', marginTop: '1.4rem' }}><input type="checkbox" name="actif" defaultChecked={p?.actif ?? true} style={{ width: 'auto' }} /> Affiché</label>
          </div>
        </div>
        <ChampImage name="logo_url" label="Logo" aide="PNG ou WebP sur fond transparent de préférence, 400 px de large suffisent." valeurInitiale={p?.logo_url} dossier="partenaires" />
      </div>
      <div style={{ display: 'flex', gap: '.5rem' }}>
        <button className="btn btn-k btn-sm" disabled={pending}>{p ? 'Enregistrer' : '+ Ajouter le partenaire'}</button>
        {onFin && <button type="button" className="btn btn-w btn-sm" onClick={onFin}>Annuler</button>}
      </div>
    </form>
  );
}

export default function GestionPartenaires({ partenaires }: { partenaires: Partenaire[] }) {
  const [edit, setEdit] = useState<string | null>(null);
  const [, start] = useTransition();
  return (
    <>
      <div className="panel">
        <h2>Ajouter un partenaire</h2>
        <Form p={null} />
      </div>
      <div className="panel">
        <h2>Partenaires ({partenaires.length})</h2>
        <table className="tbl">
          <thead><tr><th>Logo</th><th>Nom</th><th>Site</th><th>Position</th><th>Affiché</th><th></th></tr></thead>
          <tbody>
            {partenaires.map((p) => (
              <tr key={p.id}>
                {edit === p.id ? <td colSpan={6}><Form p={p} onFin={() => setEdit(null)} /></td> : (<>
                  <td><img src={p.logo_url} alt="" style={{ height: 40, maxWidth: 120, objectFit: 'contain' }} /></td>
                  <td><b>{p.nom}</b></td>
                  <td style={{ fontSize: '.8rem' }}>{p.site_url ? <a href={p.site_url} target="_blank" rel="noreferrer">{p.site_url.replace(/^https?:\/\//, '')}</a> : '—'}</td>
                  <td>{p.position}</td>
                  <td><span className={`pill ${p.actif ? 'on' : 'off'}`}>{p.actif ? 'oui' : 'non'}</span></td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    <button className="btn btn-y btn-sm" onClick={() => setEdit(p.id)}>Modifier</button>{' '}
                    <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer « ${p.nom} » ?`)) start(() => supprimerPartenaire(p.id)); }}>✕</button>
                  </td>
                </>)}
              </tr>
            ))}
            {partenaires.length === 0 && <tr><td colSpan={6}>Aucun partenaire pour le moment.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
