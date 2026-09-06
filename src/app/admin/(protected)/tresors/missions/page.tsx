import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import type { Mission } from '@/lib/tresors/types';

export default async function AdminMissions() {
  const { supabase } = await requireAdmin();
  const { data } = await supabase.from('tdn_missions').select('*').order('numero');
  const missions = (data ?? []) as Mission[];
  return (
    <>
      <div className="adm-h">
        <div><h1>Missions</h1><p>Énigmes, réponses acceptées et indices.</p></div>
        <Link className="btn btn-k btn-sm" href="/admin/tresors/missions/nouvelle">+ Nouvelle mission</Link>
      </div>
      <div className="panel">
        <table className="tbl">
          <thead><tr><th>#</th><th>Titre</th><th>Lieu</th><th>Type</th><th>Réponse</th><th>Indices</th><th>État</th><th></th></tr></thead>
          <tbody>
            {missions.map((m) => (
              <tr key={m.id}>
                <td>{m.numero}</td><td><b>{m.titre}</b></td><td>{m.lieu}</td><td>{m.question_type}</td>
                <td className="mono">{m.question_type === 'choix' ? m.options[m.bonne_reponse ?? 0] : m.reponses[0]}</td>
                <td>{m.indices.length}{m.solution_secours ? ' + secours' : ''}</td>
                <td><span className={`pill ${m.publie ? 'on' : 'off'}`}>{m.publie ? 'publiée' : 'brouillon'}</span></td>
                <td><Link className="btn btn-y btn-sm" href={`/admin/tresors/missions/${m.id}`}>Modifier</Link></td>
              </tr>
            ))}
            {missions.length === 0 && <tr><td colSpan={8}>Aucune mission. Exécutez <code>supabase/tresors.sql</code> ou créez-en une.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}
