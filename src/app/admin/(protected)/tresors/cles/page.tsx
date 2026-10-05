import { requireAdmin } from '@/lib/supabase/server';
import TableCles from '@/components/tresors/TableCles';
import type { Lot } from '@/lib/tresors/types';

export default async function AdminCles() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: cles }, { data: lots }] = await Promise.all([
    supabase.from('tdn_cles').select('*, tdn_participants(prenom, tdn_comptes(prenom, nom)), tdn_lots(nom, grand)').order('numero'),
    supabase.from('tdn_lots').select('*').order('position'),
  ]);
  const lignes = (cles ?? []).map((c) => {
    const p = c.tdn_participants as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, code: c.code, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '',
      lot_id: c.lot_id, lot: (c.tdn_lots as { nom: string } | null)?.nom ?? '', revelee: !!c.revelee_le };
  });
  const cartes = (cles ?? []).filter((c) => (c.tdn_lots as { grand?: boolean } | null)?.grand).length;
  const stockCartes = ((lots ?? []) as Lot[]).filter((l) => l.grand).reduce((s, l) => s + l.stock, 0);
  return (
    <>
      <div className="adm-h"><div><h1>Clés</h1><p>{lignes.length} clés générées · {lignes.filter((l) => l.revelee).length} révélées · {cartes} carte{cartes > 1 ? 's' : ''} du grand trésor sortie{cartes > 1 ? 's' : ''} sur {stockCartes}.</p></div></div>
      <div className="panel" style={{ borderLeft: '10px solid #FFD400' }}>
        <h2>Un seul tirage, à la révélation</h2>
        <p>Quand une clé est saisie sur l&apos;écran de révélation, son lot est tiré au sort parmi <b>tous les lots encore en stock, cartes du grand trésor comprises</b>. Un même compte ne peut remporter qu&apos;<b>une seule carte</b> : dès qu&apos;une de ses clés en a une, ses autres clés tirent parmi les autres lots.</p>
        <p style={{ marginTop: '.5rem', color: '#6b6560', fontSize: '.9rem' }}>Le tableau permet d&apos;imposer un lot à une clé avant sa révélation, ou de la remettre en « tirage au sort ». Une attribution faite à la main n&apos;est pas contrôlée par la règle « une carte par compte ».</p>
      </div>
      <TableCles lignes={lignes} lots={(lots ?? []) as Lot[]} />
    </>
  );
}
