import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { dateFr, montant, montantOuVide } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete from '@/components/compta/Entete';
import ActionsPiece from '@/components/compta/ActionsPiece';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ORIGINE: Record<string, string> = { manuel: 'Saisie', site: 'Import du site', annulation: 'Annulation' };

export default async function Piece({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const { supabase } = await requireAdmin();

  const { data: e } = await supabase.from('compta_ecritures').select('*').eq('id', id).maybeSingle();
  if (!e) notFound();

  const [{ data: lg }, { data: annulation }, justificatif] = await Promise.all([
    supabase.from('compta_v_lignes').select('*').eq('ecriture_id', id).order('position'),
    e.contrepassee_par
      ? supabase.from('compta_ecritures').select('id, piece').eq('id', e.contrepassee_par).maybeSingle()
      : Promise.resolve({ data: null }),
    e.justificatif_chemin
      ? supabase.storage.from('compta-justificatifs').createSignedUrl(e.justificatif_chemin, 3600)
      : Promise.resolve({ data: null }),
  ]);

  const lignes = (lg ?? []) as LigneVue[];
  const total = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const lien = (justificatif.data as { signedUrl?: string } | null)?.signedUrl ?? null;

  return (
    <>
      <Entete titre={`Pièce ${e.piece}`}>
        <Link className="cpt-btn" href={`/admin/compta/journaux?j=${e.journal_code}&du=${e.date_piece}&au=${e.date_piece}`}>
          Retour au journal
        </Link>
      </Entete>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille">
            <tbody>
              <tr><th style={{ width: 160 }}>Date</th><td>{dateFr(e.date_piece)}</td></tr>
              <tr><th>Journal</th><td>{e.journal_code}</td></tr>
              <tr><th>Libellé</th><td>{e.libelle}</td></tr>
              <tr><th>Origine</th><td>{ORIGINE[e.source] ?? e.source}, par {e.cree_par_nom ?? 'inconnu'}, le {dateFr(e.created_at)}</td></tr>
              <tr>
                <th>Justificatif</th>
                <td>{lien ? <a href={lien} target="_blank" rel="noreferrer">Ouvrir le justificatif</a> : 'Aucun'}</td>
              </tr>
              {annulation && (
                <tr>
                  <th>État</th>
                  <td>
                    <span className="cpt-etat rouge">Annulée</span>{' '}
                    par la pièce <Link href={`/admin/compta/piece/${annulation.id}`}>{annulation.piece}</Link>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>Lignes</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Compte</th><th>Intitulé</th><th>Libellé</th><th>Évt</th><th className="n">Débit</th><th className="n">Crédit</th></tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td className="fixe">{l.compte_numero}</td>
                  <td>{l.compte_intitule}</td>
                  <td>{l.libelle}</td>
                  <td className="fixe">{l.evenement_code ?? ''}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr><td colSpan={4}>Totaux</td><td className="n">{montant(total)}</td><td className="n">{montant(total)}</td></tr>
            </tfoot>
          </table>
        </div>
      </div>

      <ActionsPiece
        id={e.id}
        piece={e.piece}
        annee={String(e.date_piece).slice(0, 4)}
        annulable={e.source !== 'annulation' && !e.contrepassee_par}
        aJustificatif={!!e.justificatif_chemin}
      />
    </>
  );
}
