import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, referentiel, suffixeEx } from '@/lib/compta/db';
import { dateFr, solde } from '@/lib/compta/format';
import { LIBELLE_TYPE, type LigneBalance } from '@/lib/compta/types';
import Entete from '@/components/compta/Entete';
import { BasculeCompte, BasculeExercice, FormCompte, FormExercice } from '@/components/compta/FormsPlan';

export default async function Plan({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase, isAdmin } = await requireAdmin();
  const [{ exercices, exercice }, { comptes, journaux }] = await Promise.all([
    contexte(supabase, ex),
    referentiel(supabase),
  ]);

  const { data: bal } = exercice
    ? await supabase.from('compta_v_balance').select('numero, solde_centimes').eq('exercice_id', exercice.id)
    : { data: [] };
  const soldes = new Map(((bal ?? []) as Pick<LigneBalance, 'numero' | 'solde_centimes'>[]).map((l) => [l.numero, l.solde_centimes]));

  return (
    <>
      <Entete titre="Plan comptable et exercices" exercices={exercices} exercice={exercice} />

      <div className="cpt-panneau">
        <h2>Plan comptable{exercice ? `, soldes de l'exercice ${exercice.libelle}` : ''}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Compte</th><th>Intitulé</th><th>Type</th><th className="n">Solde</th><th>État</th>{isAdmin && <th></th>}</tr>
            </thead>
            <tbody>
              {comptes.map((c) => (
                <tr key={c.numero}>
                  <td className="fixe"><Link href={`/admin/compta/grand-livre?c=${c.numero}${suffixeEx(ex, false)}`}>{c.numero}</Link></td>
                  <td>{c.intitule}</td>
                  <td className="fixe">{LIBELLE_TYPE[c.type]}</td>
                  <td className="n">{soldes.has(c.numero) ? solde(soldes.get(c.numero)!) : ''}</td>
                  <td><span className={`cpt-etat ${c.actif ? 'vert' : ''}`}>{c.actif ? 'Actif' : 'Inactif'}</span></td>
                  {isAdmin && <td><BasculeCompte numero={c.numero} actif={c.actif} /></td>}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {isAdmin && (
          <div style={{ marginTop: 10 }}>
            <FormCompte />
            <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
              Saisir un numéro existant renomme le compte. Un compte désactivé reste dans les états mais n&apos;est plus proposé à la saisie.
            </p>
          </div>
        )}
      </div>

      <div className="cpt-panneau">
        <h2>Journaux</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Code</th><th>Libellé</th><th>Compte de trésorerie</th></tr></thead>
            <tbody>
              {journaux.map((j) => (
                <tr key={j.code}><td className="fixe">{j.code}</td><td>{j.libelle}</td><td className="fixe">{j.compte_tresorerie ?? ''}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>Exercices</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Exercice</th><th>Du</th><th>Au</th><th>État</th>{isAdmin && <th></th>}</tr></thead>
            <tbody>
              {exercices.map((e) => (
                <tr key={e.id}>
                  <td className="fixe">{e.libelle}</td>
                  <td className="fixe">{dateFr(e.date_debut)}</td>
                  <td className="fixe">{dateFr(e.date_fin)}</td>
                  <td>
                    <span className={`cpt-etat ${e.cloture ? 'rouge' : 'vert'}`}>
                      {e.cloture ? `Clôturé le ${dateFr(e.cloture_le)}` : 'Ouvert'}
                    </span>
                  </td>
                  {isAdmin && <td><BasculeExercice id={e.id} libelle={e.libelle} cloture={e.cloture} /></td>}
                </tr>
              ))}
              {exercices.length === 0 && <tr><td colSpan={isAdmin ? 5 : 4}>Aucun exercice.</td></tr>}
            </tbody>
          </table>
        </div>
        {isAdmin && <div style={{ marginTop: 10 }}><FormExercice /></div>}
        <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
          Un exercice clôturé n&apos;accepte plus aucune écriture. Les soldes de départ du suivant se saisissent dans le journal AN (saisie libre).
        </p>
      </div>
    </>
  );
}
