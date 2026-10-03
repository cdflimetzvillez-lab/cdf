import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { dateLongue } from '@/lib/format';
import LigneEvenement from '@/components/LigneEvenement';
import type { Evenement } from '@/lib/types';

export default async function ListeEvenements() {
  const { supabase } = await requireAdmin('evenements');
  const { data } = await supabase.from('evenements').select('*').order('position');
  const evts = (data ?? []) as Evenement[];

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Événements</h1>
          <p>Créez, modifiez, publiez ou dépubliez les rendez-vous de la saison.</p>
        </div>
        <Link className="btn btn-k btn-sm" href="/admin/evenements/nouveau">+ Nouvel événement</Link>
      </div>

      <div className="panel">
        <table className="tbl">
          <thead>
            <tr>
              <th></th><th>Titre</th><th>Date</th><th>Lieu</th><th>Statut</th><th></th>
            </tr>
          </thead>
          <tbody>
            {evts.map((e) => (
              <LigneEvenement key={e.id} evenement={e} dateLisible={dateLongue(e.date_debut)} />
            ))}
            {evts.length === 0 && (
              <tr><td colSpan={6} style={{ color: '#6b6560' }}>Aucun événement.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
