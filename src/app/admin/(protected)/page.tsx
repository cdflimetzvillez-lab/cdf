import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { dateLongue } from '@/lib/format';
import type { Evenement, Demande } from '@/lib/types';

export default async function Dashboard() {
  const { supabase, modules } = await requireAdmin('tableau');
  // Les demandes contiennent des coordonnées : elles ne s'affichent qu'aux membres qui gèrent ce module.
  const voitDemandes = modules.includes('demandes');
  const gereEvenements = modules.includes('evenements');

  const [{ data: evts }, { data: demandes }, { count: nouvelles }] = await Promise.all([
    supabase.from('evenements').select('*').order('date_debut'),
    voitDemandes
      ? supabase.from('demandes').select('*').order('created_at', { ascending: false }).limit(6)
      : Promise.resolve({ data: [] as Demande[] }),
    voitDemandes
      ? supabase.from('demandes').select('id', { count: 'exact', head: true }).eq('statut', 'nouveau')
      : Promise.resolve({ count: 0 }),
  ]);

  const evenements = (evts ?? []) as Evenement[];
  const aujourdhui = new Date().toISOString().slice(0, 10);
  const aVenir = evenements.filter((e) => e.date_debut >= aujourdhui);
  const prochain = aVenir[0];

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Tableau de bord</h1>
          <p>Vue d&apos;ensemble du site et des demandes reçues.</p>
        </div>
        {gereEvenements && (
          <Link className="btn btn-k btn-sm" href="/admin/evenements/nouveau">
            + Nouvel événement
          </Link>
        )}
      </div>

      <div className="kpi">
        <div><b>{evenements.length}</b><span>Événements</span></div>
        <div><b>{evenements.filter((e) => e.publie).length}</b><span>Publiés</span></div>
        <div><b>{aVenir.length}</b><span>À venir</span></div>
        {voitDemandes && <div><b>{nouvelles ?? 0}</b><span>Demandes non traitées</span></div>}
      </div>

      {prochain && (
        <div className="panel" style={{ borderLeft: `10px solid ${prochain.couleur}` }}>
          <h2>Prochain événement</h2>
          <p style={{ fontSize: '1.3rem', fontFamily: 'Anton, sans-serif', textTransform: 'uppercase' }}>
            {prochain.titre}
          </p>
          <p style={{ color: '#6b6560', marginTop: '.3rem' }}>
            {dateLongue(prochain.date_debut)} · {prochain.lieu} ·{' '}
            {prochain.publie ? 'publié' : 'brouillon'}
          </p>
          <div style={{ marginTop: '1rem', display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
            {gereEvenements && <Link className="btn btn-y btn-sm" href={`/admin/evenements/${prochain.id}`}>Modifier</Link>}
            <Link className="btn btn-w btn-sm" href={`/evenements/${prochain.slug}`} target="_blank">
              Voir la page
            </Link>
          </div>
        </div>
      )}

      {voitDemandes && (
      <div className="panel">
        <h2>Dernières demandes</h2>
        {(!demandes || demandes.length === 0) && (
          <p style={{ color: '#6b6560' }}>Aucune demande pour le moment.</p>
        )}
        {demandes && demandes.length > 0 && (
          <table className="tbl">
            <thead>
              <tr><th>Nom</th><th>Type</th><th>Reçue le</th><th>Statut</th></tr>
            </thead>
            <tbody>
              {(demandes as Demande[]).map((d) => (
                <tr key={d.id}>
                  <td><strong>{d.nom}</strong><br /><span style={{ color: '#6b6560' }}>{d.email}</span></td>
                  <td>{d.type}</td>
                  <td>{new Date(d.created_at).toLocaleDateString('fr-FR')}</td>
                  <td>
                    <span className={`pill ${d.statut === 'nouveau' ? 'new' : 'done'}`}>{d.statut}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <div style={{ marginTop: '1.2rem' }}>
          <Link className="btn btn-k btn-sm" href="/admin/demandes">Toutes les demandes</Link>
        </div>
      </div>
      )}
    </>
  );
}
