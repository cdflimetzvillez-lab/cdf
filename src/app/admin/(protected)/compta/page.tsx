import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, suffixeEx } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import type { LigneBalance } from '@/lib/compta/types';
import Entete, { SansExercice } from '@/components/compta/Entete';

export default async function ComptaAccueil({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase } = await requireAdmin();

  // Les ventes payées sur le site entrent au journal à chaque ouverture du tableau de bord.
  await supabase.rpc('compta_importer_ventes');

  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const [{ data: bal }, { data: aVerifier }, { count: sansJustificatif }, { count: nonPointees }, { data: dernieres }] =
    await Promise.all([
      supabase.from('compta_v_balance').select('*').eq('exercice_id', exercice.id).order('numero'),
      supabase.rpc('compta_ventes_a_verifier'),
      supabase.from('compta_ecritures').select('id', { count: 'exact', head: true })
        .eq('exercice_id', exercice.id).eq('source', 'manuel').neq('journal_code', 'AN')
        .is('justificatif_chemin', null).is('contrepassee_par', null),
      supabase.from('compta_v_lignes').select('id', { count: 'exact', head: true })
        .eq('exercice_id', exercice.id).eq('compte_numero', '512000').is('pointe_le', null),
      supabase.from('compta_ecritures')
        .select('id, piece, date_piece, libelle, cree_par_nom, compta_lignes(debit_centimes)')
        .eq('exercice_id', exercice.id).order('created_at', { ascending: false }).order('date_piece', { ascending: false })
        .order('numero', { ascending: false }).limit(8),
    ]);

  const balance = (bal ?? []) as LigneBalance[];
  const tresorerie = balance.filter((l) => l.type === 'tresorerie');
  const totalTresorerie = tresorerie.reduce((s, l) => s + l.solde_centimes, 0);
  const produits = balance.filter((l) => l.type === 'produit').reduce((s, l) => s - l.solde_centimes, 0);
  const charges = balance.filter((l) => l.type === 'charge').reduce((s, l) => s + l.solde_centimes, 0);
  const resultat = produits - charges;
  const nbAVerifier = ((aVerifier ?? []) as unknown[]).length;
  const s = suffixeEx(ex);

  return (
    <>
      <Entete titre="Tableau de bord" exercices={exercices} exercice={exercice}>
        <Link className="cpt-btn p" href={`/admin/compta/saisie${s}`}>Nouvelle écriture</Link>
      </Entete>
      <p className="cpt-info">
        Exercice {exercice.libelle}, du {dateFr(exercice.date_debut)} au {dateFr(exercice.date_fin)}.
        Statut : {exercice.cloture ? 'clôturé' : 'ouvert'}.
      </p>

      <div className="cpt-cols">
        <div className="cpt-panneau">
          <h2>Trésorerie</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Compte</th><th>Intitulé</th><th className="n">Solde</th></tr></thead>
              <tbody>
                {tresorerie.map((l) => (
                  <tr key={l.numero}>
                    <td className="fixe"><Link href={`/admin/compta/grand-livre?c=${l.numero}${suffixeEx(ex, false)}`}>{l.numero}</Link></td>
                    <td>{l.intitule}</td>
                    <td className="n">{montant(l.solde_centimes)}</td>
                  </tr>
                ))}
                {tresorerie.length === 0 && <tr><td colSpan={3}>Aucun mouvement de trésorerie sur cet exercice.</td></tr>}
              </tbody>
              <tfoot><tr><td colSpan={2}>Total</td><td className="n">{montant(totalTresorerie)}</td></tr></tfoot>
            </table>
          </div>
        </div>

        <div className="cpt-panneau">
          <h2>Résultat de l&apos;exercice</h2>
          <div className="cpt-defile">
            <table className="cpt-grille">
              <thead><tr><th>Classe</th><th>Intitulé</th><th className="n">Montant</th></tr></thead>
              <tbody>
                <tr><td>7</td><td>Produits</td><td className="n">{montant(produits)}</td></tr>
                <tr><td>6</td><td>Charges</td><td className="n">{montant(charges)}</td></tr>
              </tbody>
              <tfoot>
                <tr><td colSpan={2}>{resultat >= 0 ? 'Excédent' : 'Déficit'}</td><td className="n">{montant(Math.abs(resultat))}</td></tr>
              </tfoot>
            </table>
          </div>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>À traiter</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Nature</th><th>Détail</th><th>Écran</th></tr></thead>
            <tbody>
              <tr>
                <td>Ventes à vérifier</td>
                <td>{nbAVerifier === 0 ? 'Rien à signaler' : `${nbAVerifier} vente(s) dont le statut a changé depuis l'import`}</td>
                <td><Link href={`/admin/compta/ventes${s}`}>Ventes du site</Link></td>
              </tr>
              <tr>
                <td>Pièces sans justificatif</td>
                <td>{(sansJustificatif ?? 0) === 0 ? 'Rien à signaler' : `${sansJustificatif} écriture(s) saisie(s) sans pièce jointe`}</td>
                <td><Link href={`/admin/compta/journaux?sj=1&du=${exercice.date_debut}${suffixeEx(ex, false)}`}>Journaux</Link></td>
              </tr>
              <tr>
                <td>Rapprochement bancaire</td>
                <td>{(nonPointees ?? 0) === 0 ? 'Rien à signaler' : `${nonPointees} ligne(s) de banque non pointée(s)`}</td>
                <td><Link href={`/admin/compta/rapprochement${s}`}>Rapprochement</Link></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div className="cpt-panneau">
        <h2>Dernières pièces enregistrées</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Date</th><th>Pièce</th><th>Libellé</th><th className="n">Montant</th><th>Saisie</th></tr></thead>
            <tbody>
              {((dernieres ?? []) as any[]).map((e) => (
                <tr key={e.id}>
                  <td className="fixe">{dateFr(e.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${e.id}`}>{e.piece}</Link></td>
                  <td>{e.libelle}</td>
                  <td className="n">{montant((e.compta_lignes ?? []).reduce((t: number, l: any) => t + l.debit_centimes, 0))}</td>
                  <td>{e.cree_par_nom}</td>
                </tr>
              ))}
              {(dernieres ?? []).length === 0 && <tr><td colSpan={5}>Aucune écriture pour le moment.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
