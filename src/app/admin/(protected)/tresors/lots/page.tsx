import { requireAdmin } from '@/lib/supabase/server';
import GestionLots from '@/components/tresors/GestionLots';
import type { Lot, Partenaire } from '@/lib/tresors/types';

export default async function AdminLots() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: lots }, { data: partenaires }, { data: attribs }, { count: nbCles }] = await Promise.all([
    supabase.from('tdn_lots').select('*, tdn_partenaires(nom)').order('position'),
    supabase.from('tdn_partenaires').select('*').order('nom'),
    supabase.from('tdn_cles').select('lot_id, revelee_le').not('lot_id', 'is', null),
    supabase.from('tdn_cles').select('id', { count: 'exact', head: true }),
  ]);
  const compte: Record<string, { attribues: number; reveles: number }> = {};
  for (const a of attribs ?? []) {
    const c = (compte[a.lot_id!] ??= { attribues: 0, reveles: 0 });
    c.attribues++; if (a.revelee_le) c.reveles++;
  }
  // Urne de la révélation : un ticket par exemplaire en stock, cartes du grand trésor comprises.
  const liste = (lots ?? []) as Lot[];
  const stockTotal = liste.reduce((s, l) => s + l.stock, 0);
  const stockCartes = liste.filter((l) => l.grand).reduce((s, l) => s + l.stock, 0);
  const cles = nbCles ?? 0;
  const ecart = stockTotal - cles;
  return (
    <>
      <div className="adm-h"><div><h1>Lots et partenaires</h1><p>Tous les lots, cartes du « grand trésor » comprises, sont tirés au sort dans la même urne au moment de la révélation, dans la limite du stock. Un compte ne peut remporter qu&apos;une seule carte du grand trésor.</p></div></div>
      <div className="panel" style={{ borderLeft: `10px solid ${ecart === 0 ? '#9BD44F' : '#FFD400'}` }}>
        <h2>Stock et clés</h2>
        <p><b>{stockTotal}</b> lot{stockTotal > 1 ? 's' : ''} en stock, dont <b>{stockCartes}</b> carte{stockCartes > 1 ? 's' : ''} du grand trésor · <b>{cles}</b> clé{cles > 1 ? 's' : ''} générée{cles > 1 ? 's' : ''}.</p>
        {ecart > 0 && <p style={{ marginTop: '.5rem' }}>Il y a <b>{ecart} lot{ecart > 1 ? 's' : ''} de plus que de clés</b>. Ce n&apos;est pas bloquant, mais {ecart > 1 ? `${ecart} lots resteront` : 'un lot restera'} dans l&apos;urne à la fin, et ce peut être une carte du grand trésor. Pour que toutes les cartes sortent, ajustez le stock des autres lots au nombre de clés une fois le jeu terminé, avant d&apos;ouvrir la révélation.</p>}
        {ecart < 0 && <p style={{ marginTop: '.5rem' }}>Il manque <b>{-ecart} lot{ecart < -1 ? 's' : ''}</b> : les dernières clés révélées n&apos;auraient plus rien à tirer. Ajoutez du stock.</p>}
        {ecart === 0 && cles > 0 && <p style={{ marginTop: '.5rem' }}>Autant de lots que de clés : si toutes les clés sont révélées, tous les lots sortent, cartes comprises.</p>}
      </div>
      <GestionLots lots={liste} partenaires={(partenaires ?? []) as Partenaire[]} compte={compte} />
    </>
  );
}
