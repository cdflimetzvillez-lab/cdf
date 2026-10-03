import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout, referentiel } from '@/lib/compta/db';
import { aujourdhui, dateFr, estDateIso, montant, montantOuVide } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

type Params = { ex?: string; j?: string; du?: string; au?: string; evt?: string; sj?: string };

export default async function Journaux({ searchParams }: { searchParams: Promise<Params> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const [{ exercices, exercice }, { journaux, evenements }] = await Promise.all([
    contexte(supabase, sp.ex),
    referentiel(supabase),
  ]);
  if (!exercice) return <SansExercice />;

  // Par défaut : le mois en cours, ou tout l'exercice s'il est passé.
  const jour = aujourdhui();
  const dansExercice = exercice.date_debut <= jour && jour <= exercice.date_fin;
  const du = estDateIso(sp.du) ? sp.du : dansExercice ? `${jour.slice(0, 8)}01` : exercice.date_debut;
  const au = estDateIso(sp.au) ? sp.au : exercice.date_fin;
  const journal = journaux.some((j) => j.code === sp.j) ? sp.j! : '';
  const evt = evenements.some((e) => e.id === sp.evt) ? sp.evt! : '';
  const sansJustificatif = sp.sj === '1';

  const lignes = await lireTout<LigneVue>((de, a) => {
    let q = supabase.from('compta_v_lignes').select('*')
      .eq('exercice_id', exercice.id).gte('date_piece', du).lte('date_piece', au);
    if (journal) q = q.eq('journal_code', journal);
    if (evt) q = q.eq('compta_evenement_id', evt);
    if (sansJustificatif) {
      q = q.eq('source', 'manuel').neq('journal_code', 'AN').is('justificatif_chemin', null).is('contrepassee_par', null);
    }
    return q.order('date_piece').order('journal_code').order('numero').order('position').range(de, a);
  });

  const totalDebit = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const totalCredit = lignes.reduce((s, l) => s + l.credit_centimes, 0);
  const nbPieces = new Set(lignes.map((l) => l.ecriture_id)).size;

  return (
    <>
      <Entete titre="Journaux" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`journal-${journal || 'tous'}-${du}-${au}`}
          entetes={['Date', 'Journal', 'Pièce', 'Compte', 'Intitulé', 'Libellé', 'Événement', 'Débit', 'Crédit']}
          lignes={lignes.map((l) => [
            dateFr(l.date_piece), l.journal_code, l.piece, l.compte_numero, l.compte_intitule, l.libelle,
            l.evenement_code ?? '', montantOuVide(l.debit_centimes), montantOuVide(l.credit_centimes),
          ])}
        />
        <Imprimer />
      </Entete>

      <form method="get" className="cpt-filtres">
        {sp.ex && <input type="hidden" name="ex" value={sp.ex} />}
        <div className="cpt-champ">
          <label htmlFor="f-j">Journal</label>
          <select id="f-j" name="j" defaultValue={journal}>
            <option value="">Tous les journaux</option>
            {journaux.map((j) => <option key={j.code} value={j.code}>{j.code}, {j.libelle}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-du">Du</label>
          <input id="f-du" name="du" type="date" defaultValue={du} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-au">Au</label>
          <input id="f-au" name="au" type="date" defaultValue={au} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-evt">Événement</label>
          <select id="f-evt" name="evt" defaultValue={evt}>
            <option value="">Tous</option>
            {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="f-sj">Justificatif</label>
          <select id="f-sj" name="sj" defaultValue={sansJustificatif ? '1' : ''}>
            <option value="">Toutes les pièces</option>
            <option value="1">Saisies sans justificatif</option>
          </select>
        </div>
        <div className="cpt-champ">
          <button className="cpt-btn p">Afficher</button>
        </div>
      </form>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille large">
            <thead>
              <tr>
                <th>Date</th><th>Pièce</th><th>Compte</th><th>Intitulé</th><th>Libellé</th><th>Évt</th>
                <th className="n">Débit</th><th className="n">Crédit</th>
              </tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id} className={l.contrepassee_par ? 'annulee' : ''}>
                  <td className="fixe">{dateFr(l.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${l.ecriture_id}`}>{l.piece}</Link></td>
                  <td className="fixe">{l.compte_numero}</td>
                  <td>{l.compte_intitule}</td>
                  <td>{l.libelle}{l.contrepassee_par ? ' (annulée)' : ''}</td>
                  <td className="fixe">{l.evenement_code ?? ''}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={8}>Aucune écriture sur cette période.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={6}>Totaux de la période</td>
                <td className="n">{montant(totalDebit)}</td>
                <td className="n">{montant(totalCredit)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      <p className="cpt-info">
        {nbPieces} pièce(s), {lignes.length} ligne(s), du {dateFr(du)} au {dateFr(au)}.
        {evt && ' Seules les lignes portant ce code événement sont affichées.'}
      </p>
    </>
  );
}
