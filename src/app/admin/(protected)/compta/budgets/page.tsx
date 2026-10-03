import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { referentiel } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import { LIBELLE_STATUT_EVT } from '@/lib/compta/types';
import Entete from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import { FormBudget, FormEvenement } from '@/components/compta/FormsBudget';

type Synthese = {
  id: string; code: string; libelle: string; statut: 'a_venir' | 'en_cours' | 'termine'; date_evenement: string | null;
  recettes_prevues_centimes: number; recettes_realisees_centimes: number;
  depenses_prevues_centimes: number; depenses_realisees_centimes: number;
};
type Detail = {
  compte_numero: string; compte_intitule: string; compte_type: 'charge' | 'produit';
  prevu_centimes: number; realise_centimes: number;
};

export default async function Budgets({ searchParams }: { searchParams: Promise<{ evt?: string }> }) {
  const { evt } = await searchParams;
  const { supabase } = await requireAdmin();

  const [{ data: syn }, { comptes, evenements }] = await Promise.all([
    supabase.from('compta_v_budgets').select('*').order('code'),
    referentiel(supabase),
  ]);
  const lignes = (syn ?? []) as Synthese[];
  const choisi = evenements.find((e) => e.id === evt) ?? null;

  let detail: Detail[] = [];
  if (choisi) {
    const { data } = await supabase.from('compta_v_budget_detail').select('*')
      .eq('compta_evenement_id', choisi.id).order('compte_numero');
    detail = (data ?? []) as Detail[];
  }

  const t = lignes.reduce(
    (s, l) => ({
      rp: s.rp + l.recettes_prevues_centimes, rr: s.rr + l.recettes_realisees_centimes,
      dp: s.dp + l.depenses_prevues_centimes, dr: s.dr + l.depenses_realisees_centimes,
    }),
    { rp: 0, rr: 0, dp: 0, dr: 0 }
  );
  const recettes = detail.filter((d) => d.compte_type === 'produit');
  const depenses = detail.filter((d) => d.compte_type === 'charge');
  const somme = (ls: Detail[], k: 'prevu_centimes' | 'realise_centimes') => ls.reduce((s, l) => s + l[k], 0);

  return (
    <>
      <Entete titre="Budgets par événement">
        <ExportCsvCompta
          nom="budgets-par-evenement"
          entetes={['Code', 'Événement', 'Recettes prévues', 'Recettes réalisées', 'Dépenses prévues', 'Dépenses réalisées', 'Résultat prévu', 'Résultat réalisé']}
          lignes={lignes.map((l) => [
            l.code, l.libelle, montant(l.recettes_prevues_centimes), montant(l.recettes_realisees_centimes),
            montant(l.depenses_prevues_centimes), montant(l.depenses_realisees_centimes),
            montant(l.recettes_prevues_centimes - l.depenses_prevues_centimes),
            montant(l.recettes_realisees_centimes - l.depenses_realisees_centimes),
          ])}
        />
      </Entete>
      <p className="cpt-info">
        Chaque ligne de charge ou de produit peut porter un code événement. Le réalisé vient directement des écritures.
      </p>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille large">
            <thead>
              <tr>
                <th>Code</th><th>Événement</th><th>Statut</th>
                <th className="n">Recettes prévues</th><th className="n">Recettes réalisées</th>
                <th className="n">Dépenses prévues</th><th className="n">Dépenses réalisées</th>
                <th className="n">Résultat prévu</th><th className="n">Résultat réalisé</th>
              </tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td className="fixe"><Link href={`/admin/compta/budgets?evt=${l.id}`}>{l.code}</Link></td>
                  <td>{l.libelle}{l.date_evenement ? `, ${dateFr(l.date_evenement)}` : ''}</td>
                  <td className="fixe">{LIBELLE_STATUT_EVT[l.statut]}</td>
                  <td className="n">{montant(l.recettes_prevues_centimes)}</td>
                  <td className="n">{montant(l.recettes_realisees_centimes)}</td>
                  <td className="n">{montant(l.depenses_prevues_centimes)}</td>
                  <td className="n">{montant(l.depenses_realisees_centimes)}</td>
                  <td className="n">{montant(l.recettes_prevues_centimes - l.depenses_prevues_centimes)}</td>
                  <td className="n">{montant(l.recettes_realisees_centimes - l.depenses_realisees_centimes)}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={9}>Aucun événement.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={3}>Totaux</td>
                <td className="n">{montant(t.rp)}</td><td className="n">{montant(t.rr)}</td>
                <td className="n">{montant(t.dp)}</td><td className="n">{montant(t.dr)}</td>
                <td className="n">{montant(t.rp - t.dp)}</td><td className="n">{montant(t.rr - t.dr)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      {choisi ? (
        <>
          <div className="cpt-panneau">
            <h2>Détail de {choisi.code}, {choisi.libelle}</h2>
            <div className="cpt-defile">
              <table className="cpt-grille">
                <thead>
                  <tr><th>Compte</th><th>Poste</th><th className="n">Prévu</th><th className="n">Réalisé</th><th className="n">Reste</th></tr>
                </thead>
                <tbody>
                  <tr className="groupe"><td colSpan={5}>Recettes</td></tr>
                  {recettes.map((d) => (
                    <tr key={d.compte_numero}>
                      <td className="fixe"><Link href={`/admin/compta/journaux?evt=${choisi.id}`}>{d.compte_numero}</Link></td>
                      <td>{d.compte_intitule}</td>
                      <td className="n">{montant(d.prevu_centimes)}</td>
                      <td className="n">{montant(d.realise_centimes)}</td>
                      <td className="n">{montant(d.prevu_centimes - d.realise_centimes)}</td>
                    </tr>
                  ))}
                  {recettes.length === 0 && <tr><td colSpan={5}>Aucune recette prévue ni réalisée.</td></tr>}
                  <tr className="groupe"><td colSpan={5}>Dépenses</td></tr>
                  {depenses.map((d) => (
                    <tr key={d.compte_numero}>
                      <td className="fixe"><Link href={`/admin/compta/journaux?evt=${choisi.id}`}>{d.compte_numero}</Link></td>
                      <td>{d.compte_intitule}</td>
                      <td className="n">{montant(d.prevu_centimes)}</td>
                      <td className="n">{montant(d.realise_centimes)}</td>
                      <td className="n">{montant(d.prevu_centimes - d.realise_centimes)}</td>
                    </tr>
                  ))}
                  {depenses.length === 0 && <tr><td colSpan={5}>Aucune dépense prévue ni réalisée.</td></tr>}
                </tbody>
                <tfoot>
                  <tr>
                    <td colSpan={2}>Résultat</td>
                    <td className="n">{montant(somme(recettes, 'prevu_centimes') - somme(depenses, 'prevu_centimes'))}</td>
                    <td className="n">{montant(somme(recettes, 'realise_centimes') - somme(depenses, 'realise_centimes'))}</td>
                    <td></td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div className="cpt-panneau">
            <h2>Fixer un montant prévu</h2>
            <FormBudget evenementId={choisi.id} comptes={comptes} />
            <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>Un montant à 0 retire la ligne du budget.</p>
          </div>

          <div className="cpt-panneau">
            <h2>Modifier l&apos;événement</h2>
            <FormEvenement evenement={choisi} />
          </div>
        </>
      ) : (
        <p className="cpt-info">Clique sur un code pour voir le détail poste par poste et saisir le prévisionnel.</p>
      )}

      <div className="cpt-panneau">
        <h2>Nouvel événement</h2>
        <FormEvenement />
      </div>
    </>
  );
}
