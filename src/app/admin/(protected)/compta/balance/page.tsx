import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, suffixeEx } from '@/lib/compta/db';
import { dateFr, montant, montantOuVide } from '@/lib/compta/format';
import type { LigneBalance } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';
import ExportCsvCompta from '@/components/compta/ExportCsvCompta';
import Imprimer from '@/components/compta/Imprimer';

export default async function Balance({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase } = await requireAdmin();
  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const { data } = await supabase.from('compta_v_balance').select('*').eq('exercice_id', exercice.id).order('numero');
  const lignes = (data ?? []) as LigneBalance[];

  const debiteur = (l: LigneBalance) => Math.max(l.solde_centimes, 0);
  const crediteur = (l: LigneBalance) => Math.max(-l.solde_centimes, 0);
  const tDebit = lignes.reduce((s, l) => s + l.debit_centimes, 0);
  const tCredit = lignes.reduce((s, l) => s + l.credit_centimes, 0);
  const tSoldeD = lignes.reduce((s, l) => s + debiteur(l), 0);
  const tSoldeC = lignes.reduce((s, l) => s + crediteur(l), 0);
  const equilibree = tDebit === tCredit && tSoldeD === tSoldeC;

  return (
    <>
      <Entete titre="Balance" exercices={exercices} exercice={exercice}>
        <ExportCsvCompta
          nom={`balance-${exercice.libelle}`}
          entetes={['Compte', 'Intitulé', 'Débit', 'Crédit', 'Solde débiteur', 'Solde créditeur']}
          lignes={lignes.map((l) => [
            l.numero, l.intitule, montant(l.debit_centimes), montant(l.credit_centimes),
            montantOuVide(debiteur(l)), montantOuVide(crediteur(l)),
          ])}
        />
        <Imprimer />
      </Entete>
      <p className="cpt-info">
        Exercice {exercice.libelle}, du {dateFr(exercice.date_debut)} au {dateFr(exercice.date_fin)}, à-nouveaux inclus.
      </p>

      <div className="cpt-panneau">
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr>
                <th>Compte</th><th>Intitulé</th><th className="n">Débit</th><th className="n">Crédit</th>
                <th className="n">Solde débiteur</th><th className="n">Solde créditeur</th>
              </tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.numero}>
                  <td className="fixe"><Link href={`/admin/compta/grand-livre?c=${l.numero}${suffixeEx(ex, false)}`}>{l.numero}</Link></td>
                  <td>{l.intitule}</td>
                  <td className="n">{montantOuVide(l.debit_centimes)}</td>
                  <td className="n">{montantOuVide(l.credit_centimes)}</td>
                  <td className="n">{montantOuVide(debiteur(l))}</td>
                  <td className="n">{montantOuVide(crediteur(l))}</td>
                </tr>
              ))}
              {lignes.length === 0 && <tr><td colSpan={6}>Aucune écriture sur cet exercice.</td></tr>}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={2}>Totaux</td>
                <td className="n">{montant(tDebit)}</td>
                <td className="n">{montant(tCredit)}</td>
                <td className="n">{montant(tSoldeD)}</td>
                <td className="n">{montant(tSoldeC)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
      {lignes.length > 0 && (equilibree
        ? <p className="cpt-ok">Balance équilibrée.</p>
        : <p className="cpt-ko">Balance déséquilibrée : à signaler, cela ne devrait jamais arriver.</p>)}
    </>
  );
}
