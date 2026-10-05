import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { annulerTirage } from '@/app/tresors-actions';
import TableCles from '@/components/tresors/TableCles';
import { clesTirees, nombreGrandTresor, numeroCle, type Lot } from '@/lib/tresors/types';

export default async function AdminCles() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: cles }, { data: lots }, { data: reg }] = await Promise.all([
    supabase.from('tdn_cles').select('*, tdn_participants(prenom, tdn_comptes(prenom, nom)), tdn_lots(nom)').order('numero'),
    supabase.from('tdn_lots').select('*').order('position'),
    supabase.from('tdn_reglages').select('*').eq('id', 1).single(),
  ]);
  const nombre = nombreGrandTresor(reg ?? {});
  // Clés gagnantes, dans l'ordre du tirage.
  const gagnantes = clesTirees(reg).map((id) => (cles ?? []).find((c) => c.id === id)).filter((c) => !!c);
  const lignes = (cles ?? []).map((c) => {
    const p = c.tdn_participants as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, code: c.code, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '',
      lot_id: c.lot_id, lot: (c.tdn_lots as { nom: string } | null)?.nom ?? '', revelee: !!c.revelee_le };
  });
  return (
    <>
      <div className="adm-h"><div><h1>Clés</h1><p>{lignes.length} clés générées · {lignes.filter((l) => l.revelee).length} révélées. Le grand trésor ({nombre} lot{nombre > 1 ? 's' : ''}) se tire au sort ci-dessous ; un lot peut aussi être attribué à la main dans le tableau.</p></div></div>
      <div className="panel" style={{ borderLeft: `10px solid ${reg?.tirage_le ? '#9BD44F' : '#FFD400'}` }}>
        <h2>Tirage du grand trésor</h2>
        {reg?.tirage_le ? (
          <p>
            Effectué le {new Date(reg.tirage_le).toLocaleString('fr-FR', { timeZone: 'Europe/Paris' })} · clé{gagnantes.length > 1 ? 's' : ''} gagnante{gagnantes.length > 1 ? 's' : ''} :{' '}
            {gagnantes.length === 0 ? <b className="mono">?</b> : gagnantes.map((g, i) => {
              const p = g!.tdn_participants as { prenom: string } | null;
              return <span key={g!.id}>{i > 0 && ', '}<b className="mono">n° {numeroCle(g!.numero)}</b>{p?.prenom && ` (${p.prenom})`}</span>;
            })}.
          </p>
        ) : (
          <p>Pas encore effectué. Toutes les clés générées participent : {nombre > 1 ? `${nombre} clés différentes sont tirées au sort, une par lot` : 'une clé est tirée au sort'}. Le résultat est enregistré et verrouillé dès le clic sur « Lancer le tirage ».</p>
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
