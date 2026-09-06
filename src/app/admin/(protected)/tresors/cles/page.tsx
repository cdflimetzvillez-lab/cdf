import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { annulerTirage } from '@/app/tresors-actions';
import TableCles from '@/components/tresors/TableCles';
import type { Lot } from '@/lib/tresors/types';

export default async function AdminCles() {
  const { supabase } = await requireAdmin();
  const [{ data: cles }, { data: lots }, { data: reg }] = await Promise.all([
    supabase.from('tdn_cles').select('*, tdn_participants(prenom, tdn_comptes(prenom, nom)), tdn_lots(nom)').order('numero'),
    supabase.from('tdn_lots').select('*').order('position'),
    supabase.from('tdn_reglages').select('tirage_cle_id, tirage_le').eq('id', 1).single(),
  ]);
  const gagnante = reg?.tirage_cle_id ? (cles ?? []).find((c) => c.id === reg.tirage_cle_id) : null;
  const lignes = (cles ?? []).map((c) => {
    const p = c.tdn_participants as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, code: c.code, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '',
      lot_id: c.lot_id, lot: (c.tdn_lots as { nom: string } | null)?.nom ?? '', revelee: !!c.revelee_le };
  });
  return (
    <>
      <div className="adm-h"><div><h1>Clés</h1><p>{lignes.length} clés générées · {lignes.filter((l) => l.revelee).length} révélées. Attribuez ici le grand trésor à une clé précise.</p></div></div>
      <div className="panel" style={{ borderLeft: `10px solid ${reg?.tirage_le ? '#9BD44F' : '#FFD400'}` }}>
        <h2>Tirage du grand trésor</h2>
        {reg?.tirage_le ? (
          <p>Effectué le {new Date(reg.tirage_le).toLocaleString('fr-FR')} · clé gagnante <b className="mono">n° {gagnante ? String(gagnante.numero).padStart(3, '0') : '?'}</b>.</p>
        ) : (
          <p>Pas encore effectué. Toutes les clés générées participent. Le résultat est enregistré et verrouillé dès le clic sur « Lancer le tirage ».</p>
        )}
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', marginTop: '1rem' }}>
          <Link className="btn btn-k btn-sm" href="/tresors-de-noel/tirage" target="_blank">↗ Ouvrir l&apos;écran du tirage</Link>
          {reg?.tirage_le && (
            <form action={async () => { 'use server'; await annulerTirage(); }}>
              <button className="btn btn-w btn-sm">Annuler le tirage</button>
            </form>
          )}
        </div>
      </div>
      <TableCles lignes={lignes} lots={(lots ?? []) as Lot[]} />
    </>
  );
}
