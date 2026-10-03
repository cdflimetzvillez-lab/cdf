import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout, referentiel } from '@/lib/compta/db';
import { aujourdhui, dateFr, enCentimes, estDateIso, montant } from '@/lib/compta/format';
import type { LigneVue } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import Imprimer from '@/components/compta/Imprimer';
import { BoutonValiderRapprochement, TablePointage } from '@/components/compta/TablePointage';

type Params = { ex?: string; c?: string; date?: string; solde?: string };

/** Les lignes déjà pointées restent affichées 45 jours pour pouvoir corriger une erreur. */
const JOURS_VISIBLES = 45;

export default async function Rapprochement({ searchParams }: { searchParams: Promise<Params> }) {
  const sp = await searchParams;
  const { supabase } = await requireAdmin();
  const [{ exercices, exercice }, { comptes }] = await Promise.all([
    contexte(supabase, sp.ex),
    referentiel(supabase),
  ]);
  if (!exercice) return <SansExercice />;

  const tresos = comptes.filter((c) => c.type === 'tresorerie');
  const compte = tresos.find((c) => c.numero === sp.c) ?? tresos.find((c) => c.numero === '512000') ?? tresos[0];
  if (!compte) return <SansExercice />;

  const jour = aujourdhui();
  const parDefaut = jour > exercice.date_fin ? exercice.date_fin : jour < exercice.date_debut ? exercice.date_debut : jour;
  const date = estDateIso(sp.date) ? sp.date : parDefaut;
  const soldeReleve = sp.solde?.trim() ? enCentimes(sp.solde.replace(/^-/, '')) : null;
  const soldeSigne = soldeReleve !== null && sp.solde?.trim().startsWith('-') ? -soldeReleve : soldeReleve;

  const lignes = await lireTout<LigneVue>((de, a) =>
    supabase.from('compta_v_lignes').select('*')
      .eq('exercice_id', exercice.id).eq('compte_numero', compte.numero).lte('date_piece', date)
      .order('date_piece').order('journal_code').order('numero').order('position').range(de, a)
  );

  const soldeComptable = lignes.reduce((s, l) => s + l.debit_centimes - l.credit_centimes, 0);
  const nonPointees = lignes.filter((l) => !l.pointe_le);
  const debitsNonPointes = nonPointees.reduce((s, l) => s + l.debit_centimes, 0);
  const creditsNonPointes = nonPointees.reduce((s, l) => s + l.credit_centimes, 0);
  const soldeTheorique = soldeComptable - debitsNonPointes + creditsNonPointes;
  const ecart = soldeSigne === null ? null : soldeSigne - soldeTheorique;

  const limite = new Date(`${date}T12:00:00Z`);
  limite.setUTCDate(limite.getUTCDate() - JOURS_VISIBLES);
  const depuis = limite.toISOString().slice(0, 10);
  const affichees = lignes.filter((l) => !l.pointe_le || l.date_piece >= depuis);

  const { data: historique } = await supabase.from('compta_rapprochements').select('*')
    .eq('compte_numero', compte.numero).order('date_releve', { ascending: false }).limit(6);

  return (
    <>
      <Entete titre="Rapprochement bancaire" exercices={exercices} exercice={exercice}>
        <Imprimer />
      </Entete>

      <form method="get" className="cpt-filtres">
        {sp.ex && <input type="hidden" name="ex" value={sp.ex} />}
        <div className="cpt-champ">
          <label htmlFor="r-c">Compte</label>
          <select id="r-c" name="c" defaultValue={compte.numero}>
            {tresos.map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="r-date">Relevé au</label>
          <input id="r-date" name="date" type="date" defaultValue={date} min={exercice.date_debut} max={exercice.date_fin} />
        </div>
        <div className="cpt-champ">
          <label htmlFor="r-solde">Solde du relevé</label>
          <input id="r-solde" name="solde" className="n" type="text" inputMode="decimal" placeholder="0,00" defaultValue={sp.solde ?? ''} />
        </div>
        <div className="cpt-champ">
          <button className="cpt-btn p">Afficher</button>
        </div>
      </form>

      <div className="cpt-panneau">
        <h2>Écritures de {compte.numero}, {compte.intitule}, jusqu&apos;au {dateFr(date)}</h2>
        <TablePointage
          lignes={affichees.map((l) => ({
            id: l.id, ecriture_id: l.ecriture_id, date_piece: l.date_piece, piece: l.piece, libelle: l.libelle,
            debit_centimes: l.debit_centimes, credit_centimes: l.credit_centimes, pointe: !!l.pointe_le,
          }))}
        />
        <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
          Coche chaque ligne présente sur le relevé de la banque. Les lignes pointées depuis plus de {JOURS_VISIBLES} jours ne sont plus affichées.
        </p>
      </div>

      <div className="cpt-panneau">
        <h2>État de rapprochement au {dateFr(date)}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th></th><th className="n">Montant</th></tr></thead>
            <tbody>
              <tr><td>Solde comptable du compte {compte.numero}</td><td className="n">{montant(soldeComptable)}</td></tr>
              <tr><td>Plus : paiements émis non encore débités</td><td className="n">{montant(creditsNonPointes)}</td></tr>
              <tr><td>Moins : encaissements non encore crédités</td><td className="n">{montant(debitsNonPointes)}</td></tr>
              <tr><td>Solde attendu sur le relevé</td><td className="n">{montant(soldeTheorique)}</td></tr>
              <tr><td>Solde du relevé saisi</td><td className="n">{soldeSigne === null ? 'à saisir' : montant(soldeSigne)}</td></tr>
            </tbody>
            <tfoot>
              <tr><td>Écart</td><td className="n">{ecart === null ? '' : montant(ecart)}</td></tr>
            </tfoot>
          </table>
        </div>
        {ecart === null && <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>Saisis le solde figurant sur le relevé puis clique sur Afficher.</p>}
        {ecart === 0 && <p className="cpt-ok">Écart nul. Le rapprochement peut être validé.</p>}
        {ecart !== null && ecart !== 0 && <p className="cpt-ko">Écart de {montant(ecart)} € : une ligne manque, est en trop ou est mal pointée.</p>}
        <BoutonValiderRapprochement compte={compte.numero} date={date} solde={soldeSigne} possible={ecart === 0} />
      </div>

      <div className="cpt-panneau">
        <h2>Rapprochements validés</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Relevé au</th><th className="n">Solde du relevé</th><th>Validé par</th><th>Le</th></tr></thead>
            <tbody>
              {((historique ?? []) as any[]).map((h) => (
                <tr key={h.id}>
                  <td className="fixe">{dateFr(h.date_releve)}</td>
                  <td className="n">{montant(h.solde_releve_centimes)}</td>
                  <td>{h.valide_par_nom}</td>
                  <td className="fixe">{dateFr(h.created_at)}</td>
                </tr>
              ))}
              {(historique ?? []).length === 0 && <tr><td colSpan={4}>Aucun rapprochement validé pour ce compte.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
