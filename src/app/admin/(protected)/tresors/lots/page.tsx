import { requireAdmin } from '@/lib/supabase/server';
import GestionLots from '@/components/tresors/GestionLots';
import type { Lot, Partenaire } from '@/lib/tresors/types';

export default async function AdminLots() {
  const { supabase } = await requireAdmin();
  const [{ data: lots }, { data: partenaires }, { data: attribs }] = await Promise.all([
    supabase.from('tdn_lots').select('*, tdn_partenaires(nom)').order('position'),
    supabase.from('tdn_partenaires').select('*').order('nom'),
    supabase.from('tdn_cles').select('lot_id, revelee_le').not('lot_id', 'is', null),
  ]);
  const compte: Record<string, { attribues: number; reveles: number }> = {};
  for (const a of attribs ?? []) {
    const c = (compte[a.lot_id!] ??= { attribues: 0, reveles: 0 });
    c.attribues++; if (a.revelee_le) c.reveles++;
  }
  return (
    <>
      <div className="adm-h"><div><h1>Lots et partenaires</h1><p>Les lots sont attribués au moment de la révélation, dans la limite du stock. Le « grand trésor » ne se tire pas au sort : attribuez-le à une clé depuis l&apos;onglet Clés.</p></div></div>
      <GestionLots lots={(lots ?? []) as Lot[]} partenaires={(partenaires ?? []) as Partenaire[]} compte={compte} />
    </>
  );
}
