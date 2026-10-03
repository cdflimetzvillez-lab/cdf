import { requireAdmin } from '@/lib/supabase/server';
import PanneauMaintenance from '@/components/PanneauMaintenance';

export const dynamic = 'force-dynamic';

export default async function AdminMaintenance() {
  const { supabase } = await requireAdmin('maintenance');
  const { data } = await supabase
    .from('site_settings')
    .select('maintenance_active, maintenance_titre, maintenance_message, maintenance_retour, maintenance_depuis')
    .eq('id', 1)
    .single();

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Mode maintenance</h1>
          <p>
            Coupe le site public et affiche une page d&apos;attente.
            Le back-office reste accessible.
          </p>
        </div>
      </div>
      <PanneauMaintenance reglages={data as any} />
    </>
  );
}
