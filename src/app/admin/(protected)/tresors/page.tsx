import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import type { Stats } from '@/lib/tresors/types';

export default async function AdminTresors() {
  const { supabase } = await requireAdmin();
  const [{ data: stats }, { data: reglages }, { count: nbMissions }, { count: nbLots }] = await Promise.all([
    supabase.from('tdn_stats').select('*').single(),
    supabase.from('tdn_reglages').select('*').eq('id', 1).single(),
    supabase.from('tdn_missions').select('id', { count: 'exact', head: true }),
    supabase.from('tdn_lots').select('id', { count: 'exact', head: true }),
  ]);
  const s = (stats ?? {}) as Partial<Stats>;

  return (
    <>
      <div className="adm-h">
        <div><h1>Trésors de Noël</h1><p>Chasse aux trésors du Marché de Noël.</p></div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          <Link className="btn btn-w btn-sm" href="/tresors-de-noel" target="_blank">↗ Page du jeu</Link>
          <Link className="btn btn-y btn-sm" href="/tresors-de-noel/revelation" target="_blank">↗ Écran de révélation</Link>
        </div>
      </div>

      <div className="kpi">
        <div><b>{s.inscrits ?? 0}</b><span>Participants inscrits</span></div>
        <div><b>{euros(s.ca_centimes ?? 0)}</b><span>Chiffre d&apos;affaires</span></div>
        <div><b>{s.commences ?? 0}</b><span>Ont commencé</span></div>
        <div><b>{s.termines ?? 0}</b><span>Ont terminé</span></div>
        <div><b>{s.cles_generees ?? 0}</b><span>Clés générées</span></div>
        <div><b>{s.cles_revelees ?? 0}</b><span>Clés révélées</span></div>
      </div>

      <div className="row2">
        <div className="panel">
          <h2>État</h2>
          <p>Inscriptions : <span className={`pill ${reglages?.inscriptions_ouvertes ? 'on' : 'off'}`}>{reglages?.inscriptions_ouvertes ? 'ouvertes' : 'fermées'}</span></p>
          <p style={{ marginTop: '.5rem' }}>Jeu : <span className={`pill ${reglages?.jeu_actif ? 'on' : 'off'}`}>{reglages?.jeu_actif ? 'actif' : 'fermé'}</span></p>
          <p style={{ marginTop: '.5rem' }}>{nbMissions ?? 0} missions · {nbLots ?? 0} lots</p>
          <Link className="btn btn-y btn-sm" href="/admin/tresors/reglages" style={{ marginTop: '1rem' }}>Modifier les réglages</Link>
        </div>
        <div className="panel">
          <h2>Raccourcis</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '.6rem', alignItems: 'flex-start' }}>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/missions/nouvelle">+ Nouvelle mission</Link>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/lots">Gérer les lots</Link>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/cles">Attribuer le grand trésor</Link>
          </div>
        </div>
      </div>
    </>
  );
}
