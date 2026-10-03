import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { contexte, lireTout } from '@/lib/compta/db';
import { dateFr, montant } from '@/lib/compta/format';
import Entete, { SansExercice } from '@/components/compta/Entete';
import { BoutonImport, BoutonsVente } from '@/components/compta/ActionsVente';
import { FormSource } from '@/components/compta/FormsPlan';

type Source = {
  cle: string; libelle: string; actif: boolean; journal_code: string; compte_produit: string;
  taux_frais: number; frais_fixe_centimes: number; compta_evenements: { code: string } | null;
};
type AVerifier = {
  ecriture_id: string; piece: string; date_piece: string; libelle: string;
  montant_centimes: number; statut_importe: string | null; statut_actuel: string | null;
};
type EcritureSite = {
  id: string; piece: string; date_piece: string; libelle: string; source_table: string;
  contrepassee_par: string | null; compta_lignes: { position: number; debit_centimes: number }[];
};

export default async function Ventes({ searchParams }: { searchParams: Promise<{ ex?: string }> }) {
  const { ex } = await searchParams;
  const { supabase, isAdmin } = await requireAdmin();

  // Import à chaque ouverture : une vente déjà importée n'est jamais reprise.
  const { data: importees, error: erreurImport } = await supabase.rpc('compta_importer_ventes');

  const { exercices, exercice } = await contexte(supabase, ex);
  if (!exercice) return <SansExercice />;

  const [{ data: src }, { data: verif }, ecritures] = await Promise.all([
    supabase.from('compta_sources').select('*, compta_evenements(code)').order('libelle'),
    supabase.rpc('compta_ventes_a_verifier'),
    lireTout<EcritureSite>((de, a) =>
      supabase.from('compta_ecritures')
        .select('id, piece, date_piece, libelle, source_table, contrepassee_par, compta_lignes(position, debit_centimes)')
        .eq('exercice_id', exercice.id).eq('source', 'site')
        .order('date_piece', { ascending: false }).order('numero', { ascending: false }).range(de, a)
    ),
  ]);

  const sources = (src ?? []) as Source[];
  const aVerifier = (verif ?? []) as AVerifier[];
  const debit = (e: EcritureSite, position: number) =>
    e.compta_lignes.find((l) => l.position === position)?.debit_centimes ?? 0;

  // Totaux par source, hors ventes annulées. Ligne 1 = montant brut, ligne 3 = frais de paiement.
  const stats = new Map<string, { nb: number; brut: number; frais: number }>();
  for (const e of ecritures) {
    if (e.contrepassee_par) continue;
    const s = stats.get(e.source_table) ?? { nb: 0, brut: 0, frais: 0 };
    s.nb += 1;
    s.brut += debit(e, 1);
    s.frais += debit(e, 3);
    stats.set(e.source_table, s);
  }
  const total = [...stats.values()].reduce((t, s) => ({ nb: t.nb + s.nb, brut: t.brut + s.brut, frais: t.frais + s.frais }), { nb: 0, brut: 0, frais: 0 });

  return (
    <>
      <Entete titre="Ventes du site" exercices={exercices} exercice={exercice}>
        <BoutonImport />
      </Entete>
      {erreurImport
        ? <div className="cpt-msg ko">L&apos;import a échoué : {erreurImport.message}</div>
        : (
          <p className="cpt-info">
            {(importees as number) > 0 ? `${importees} nouvelle(s) vente(s) importée(s) à l'instant. ` : 'Journal à jour. '}
            Les ventes payées sur le site génèrent leurs écritures toutes seules, sans ressaisie.
          </p>
        )}

      <div className="cpt-panneau">
        <h2>À vérifier</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr><th>Date</th><th>Pièce</th><th>Vente</th><th className="n">Montant</th><th>Statut à l&apos;import</th><th>Statut actuel</th><th>Action</th></tr>
            </thead>
            <tbody>
              {aVerifier.map((v) => (
                <tr key={v.ecriture_id}>
                  <td className="fixe">{dateFr(v.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${v.ecriture_id}`}>{v.piece}</Link></td>
                  <td>{v.libelle}</td>
                  <td className="n">{montant(v.montant_centimes)}</td>
                  <td>{v.statut_importe ?? ''}</td>
                  <td><span className="cpt-etat jaune">{v.statut_actuel ?? 'vente supprimée'}</span></td>
                  <td><BoutonsVente id={v.ecriture_id} piece={v.piece} /></td>
                </tr>
              ))}
              {aVerifier.length === 0 && <tr><td colSpan={7}>Rien à vérifier : aucune vente importée n&apos;a changé de statut.</td></tr>}
            </tbody>
          </table>
        </div>
        <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
          Une vente remboursée ou annulée après son import apparaît ici. « Annuler la vente » passe l&apos;écriture inverse,
          « Ignorer » la laisse au journal.
        </p>
      </div>

      <div className="cpt-panneau">
        <h2>Sources importées, exercice {exercice.libelle}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille large">
            <thead>
              <tr>
                <th>Source</th><th>Journal</th><th>Compte</th><th>Évt</th>
                <th className="n">Ventes</th><th className="n">Brut</th><th className="n">Frais</th>
                <th>{isAdmin ? 'Réglages' : 'Import'}</th>
              </tr>
            </thead>
            <tbody>
              {sources.map((s) => {
                const st = stats.get(s.cle) ?? { nb: 0, brut: 0, frais: 0 };
                return (
                  <tr key={s.cle}>
                    <td>{s.libelle}</td>
                    <td className="fixe">{s.journal_code}</td>
                    <td className="fixe">{s.compte_produit}</td>
                    <td className="fixe">{s.compta_evenements?.code ?? 'selon la vente'}</td>
                    <td className="n">{st.nb}</td>
                    <td className="n">{montant(st.brut)}</td>
                    <td className="n">{montant(st.frais)}</td>
                    <td>
                      {isAdmin
                        ? <FormSource cle={s.cle} actif={s.actif} taux={Number(s.taux_frais)} fixe={montant(s.frais_fixe_centimes)} />
                        : <span className={`cpt-etat ${s.actif ? 'vert' : ''}`}>{s.actif ? 'Actif' : 'Inactif'}</span>}
                    </td>
                  </tr>
                );
              })}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4}>Totaux</td>
                <td className="n">{total.nb}</td><td className="n">{montant(total.brut)}</td><td className="n">{montant(total.frais)}</td><td></td>
              </tr>
            </tfoot>
          </table>
        </div>
        <ul className="cpt-regles" style={{ marginTop: 10 }}>
          <li>Vente payée : débit du compte d&apos;encaissement, crédit du compte de produit, au montant brut.</li>
          <li>Frais de paiement : calculés avec le taux réglé ici, portés en charge dans la même pièce. À 0, aucun frais n&apos;est écrit.</li>
          <li>Un changement de taux ne s&apos;applique qu&apos;aux ventes importées ensuite.</li>
          <li>
            Réservation payée en espèces ou par chèque : encaissée en caisse (530000) ou en chèques à encaisser (511200), sans frais.
            La remise des chèques en banque se saisit en virement interne, de 511200 vers 512000.
          </li>
        </ul>
      </div>

      <div className="cpt-panneau">
        <h2>Dernières ventes importées</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead><tr><th>Date</th><th>Pièce</th><th>Vente</th><th className="n">Brut</th><th className="n">Frais</th></tr></thead>
            <tbody>
              {ecritures.slice(0, 15).map((e) => (
                <tr key={e.id} className={e.contrepassee_par ? 'annulee' : ''}>
                  <td className="fixe">{dateFr(e.date_piece)}</td>
                  <td className="fixe"><Link href={`/admin/compta/piece/${e.id}`}>{e.piece}</Link></td>
                  <td>{e.libelle}{e.contrepassee_par ? ' (annulée)' : ''}</td>
                  <td className="n">{montant(debit(e, 1))}</td>
                  <td className="n">{montant(debit(e, 3))}</td>
                </tr>
              ))}
              {ecritures.length === 0 && <tr><td colSpan={5}>Aucune vente importée sur cet exercice.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}
