import { requireAdmin } from '@/lib/supabase/server';
import FormReglagesTdn from '@/components/tresors/FormReglagesTdn';
import type { Reglages } from '@/lib/tresors/types';

export default async function AdminReglagesTdn() {
  const { supabase } = await requireAdmin();
  const { data } = await supabase.from('tdn_reglages').select('*').eq('id', 1).single();
  return (
    <>
      <div className="adm-h"><div><h1>Réglages du jeu</h1><p>Textes, tarifs et ouverture.</p></div></div>
      <FormReglagesTdn r={data as Reglages} />
    </>
  );
}
