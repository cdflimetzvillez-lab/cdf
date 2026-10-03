import { requireAdmin } from '@/lib/supabase/server';
import { contexte } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import type { LigneBalance } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

export default async function Resultat({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase } = await requireAdmin();
  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const { data } = await supabase.from('compta_v_balance').select('*').eq('exercice_id', exercice.id).order('numero');
  const lignes = (data ?? []) as LigneBalance[];
  const charges = lignes.filter((l) => l.type === 'charge').map((l) => ({ ...l, montant: l.solde_centimes }));
  const produits = lignes.filter((l) => l.type === 'produit').map((l) => ({ ...l, montant: -l.solde_centimes }));
  const totalCharges = charges.reduce((s, l) => s + l.montant, 0);
  const totalProduits = produits.reduce((s, l) => s + l.montant, 0);
  const resultat = totalProduits - totalCharges;
  const total = Math.max(totalCharges, totalProduits);

  return (
    <>
      <Entete titre="Compte de résultat" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`compte-de-resultat-${exercice.libelle}`}
          entetes={['Nature', 'Compte', 'Intitulé', 'Montant']}
          lignes={[
            ...charges.map((l) => ['Charge', l.numero, l.intitule, montant(l.montant)]),
            ...produits.map((l) => ['Produit', l.numero, l.intitule, montant(l.montant)]),
            [resultat >= 0 ? 'Excédent' : 'Déficit', '', '', montant(Math.abs(resultat))],
          ]}
        />
        <Imprimer />
      </Entete>
      <p className="cpt-info">
        Exercice {exercice.libelle}, du {dateFr(exercice.date_debut)} au {dateFr(exercice.date_fin)}.
        {exercice.cloture ? ' Exercice clôturé.' : ' Situation provisoire, exercice en cours.'}
      </p>

      <div className="cpt-cols">
        <div className="cpt-panneau">
          <h2>Charges</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Compte</th><th>Intitulé</th><th className="n">Montant</th></tr></thead>
              <tbody>
                {charges.map((l) => (
                  <tr key={l.numero}><td className="fixe">{l.numero}</td><td>{l.intitule}</td><td className="n">{montant(l.montant)}</td></tr>
                ))}
                {charges.length === 0 && <tr><td colSpan={3}>Aucune charge.</td></tr>}
              </tbody>
              <tfoot>
                <tr><td colSpan={2}>Total des charges</td><td className="n">{montant(totalCharges)}</td></tr>
                {resultat > 0 && <tr><td colSpan={2}>Excédent</td><td className="n">{montant(resultat)}</td></tr>}
                <tr><td colSpan={2}>Total</td><td className="n">{montant(total)}</td></tr>
              </tfoot>
            </table>
          </div>
        </div>

        <div className="cpt-panneau">
          <h2>Produits</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Compte</th><th>Intitulé</th><th className="n">Montant</th></tr></thead>
              <tbody>
                {produits.map((l) => (
                  <tr key={l.numero}><td className="fixe">{l.numero}</td><td>{l.intitule}</td><td className="n">{montant(l.montant)}</td></tr>
                ))}
                {produits.length === 0 && <tr><td colSpan={3}>Aucun produit.</td></tr>}
              </tbody>
              <tfoot>
                <tr><td colSpan={2}>Total des produits</td><td className="n">{montant(totalProduits)}</td></tr>
                {resultat < 0 && <tr><td colSpan={2}>Déficit</td><td className="n">{montant(-resultat)}</td></tr>}
                <tr><td colSpan={2}>Total</td><td className="n">{montant(total)}</td></tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>

      <p className={resultat >= 0 ? 'cpt-ok' : 'cpt-ko'}>
        {resultat >= 0 ? 'Excédent' : 'Déficit'} de l&apos;exercice : {montant(Math.abs(resultat))} €
      </p>
    </>
  );
}
