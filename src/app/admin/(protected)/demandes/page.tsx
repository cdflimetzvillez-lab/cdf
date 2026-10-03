import { requireAdmin } from '@/lib/supabase/server';
import LigneDemande from '@/components/LigneDemande';
import type { Demande } from '@/lib/types';

export default async function Demandes() {
  const { supabase } = await requireAdmin('demandes');
  const { data } = await supabase.from('demandes')
    .select('*').order('created_at', { ascending: false });
  const demandes = (data ?? []) as Demande[];
  const nouvelles = demandes.filter((d) => d.statut === 'nouveau').length;

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Demandes reçues</h1>
          <p>
            {demandes.length} demande{demandes.length > 1 ? 's' : ''} au total
            {nouvelles > 0 && `, dont ${nouvelles} à traiter`}.
          </p>
        </div>
      </div>

      <div className="panel">
        <table className="tbl">
          <thead>
            <tr>
              <th>Contact</th><th>Type</th><th>Message</th><th>Reçue le</th>
              <th>Statut</th><th></th>
            </tr>
          </thead>
          <tbody>
            {demandes.map((d) => <LigneDemande key={d.id} demande={d} />)}
            {demandes.length === 0 && (
              <tr><td colSpan={6} style={{ color: '#6b6560' }}>Aucune demande pour le moment.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
