import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout, referentiel } from '@/lib/compta/db';
import { dateFr, estDateIso, montant, montantOuVide, solde } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

type Params = { ex?: string; c?: string; du?: string; au?: string };

export default async function GrandLivre({ searchParams }: { searchParams: Promise<Params> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const [{ exercices, exercice }, { comptes }] = await Promise.all([
    contexte(supabase, sp.ex),
    referentiel(supabase),
  ]);
  if (!exercice) return <SansExercice />;

  const compte = comptes.find((c) => c.numero === sp.c) ?? comptes.find((c) => c.numero === '512000') ?? comptes[0];
  if (!compte) return <SansExercice />;
  const du = estDateIso(sp.du) ? sp.du : exercice.date_debut;
  const au = estDateIso(sp.au) ? sp.au : exercice.date_fin;

  const toutes = await lireTout<LigneVue>((de, a) =>
    supabase.from('compta_v_lignes').select('*')
      .eq('exercice_id', exercice.id).eq('compte_numero', compte.numero).lte('date_piece', au)
      .order('date_piece').order('journal_code').order('numero').order('position').range(de, a)
  );

  // Solde reporté : tout ce qui précède la période affichée.
  const report = toutes.filter((l) => l.date_piece < du).reduce((s, l) => s + l.debit_centimes - l.credit_centimes, 0);
  let cumul = report;
  const lignes = toutes.filter((l) => l.date_piece >= du).map((l) => {
    cumul += l.debit_centimes - l.credit_centimes;
    return { ...l, cumul };
  });
  const totalDebit = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const totalCredit = lignes.reduce((s, l) => s + l.credit_centimes, 0);

  return (
    <>
      <Entete titre="Grand livre" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`grand-livre-${compte.numero}-${du}-${au}`}
          entetes={['Date', 'Pièce', 'Libellé', 'Événement', 'Débit', 'Crédit', 'Solde']}
          lignes={lignes.map((l) => [
            dateFr(l.date_piece), l.piece, l.libelle, l.evenement_code ?? '',
            montantOuVide(l.debit_centimes), montantOuVide(l.credit_centimes), solde(l.cumul),
          ])}
        />
        <Imprimer />
      </Entete>

      <form method="get" className="cpt-filtres">
        {sp.ex && <input type="hidden" name="ex" value={sp.ex} />}
        <div className="cpt-champ l2">
          <label htmlFor="g-c">Compte</label>
          <select id="g-c" name="c" defaultValue={compte.numero}>
            {comptes.map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="g-du">Du</label>
          <input id="g-du" name="du" type="date" defaultValue={du} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="g-au">Au</label>
          <input id="g-au" name="au" type="date" defaultValue={au} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <button className="cpt-btn p">Afficher</button>
        </div>
      </form>

      <div className="cpt-panneau">
        <h2>{compte.numero}, {compte.intitule}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Date</th><th>Pièce</th><th>Libellé</th><th>Évt</th><th className="n">Débit</th><th className="n">Crédit</th><th className="n">Solde</th></tr>
            </thead>
            <tbody>
              <tr className="groupe">
                <td className="fixe">{dateFr(du)}</td><td></td><td>Solde reporté</td><td></td><td></td><td></td>
                <td className="n">{solde(report)}</td>
              </tr>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td className="fixe">{dateFr(l.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${l.ecriture_id}`}>{l.piece}</Link></td>
                  <td>{l.libelle}</td>
                  <td className="fixe">{l.evenement_code ?? ''}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                  <td className="n">{solde(l.cumul)}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={7}>Aucun mouvement sur cette période.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4}>Total de la période</td>
                <td className="n">{montant(totalDebit)}</td>
                <td className="n">{montant(totalCredit)}</td>
                <td className="n">{solde(cumul)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      <p className="cpt-info">Solde suivi de D pour débiteur, C pour créditeur.</p>
    </>
  );
}
