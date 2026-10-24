'use client';
import { useState } from 'react';

type Props = {
  reservations: any[];
  evenements?: { id: string; titre: string }[];
};

const echappe = (v: any) => `"${String(v ?? '').replace(/"/g, '""')}"`;

function telecharger(nom: string, lignes: string[][]) {
  // BOM UTF-8 pour qu'Excel affiche correctement les accents
  const csv = '\uFEFF' + lignes.map((l) => l.map(echappe).join(';')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = nom;
  a.click();
  URL.revokeObjectURL(url);
}

const slugifie = (s: string) =>
  s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
   .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

export default function ExportCsv({ reservations, evenements = [] }: Props) {
  const [ouvert, setOuvert] = useState(false);

  /** Liste d'émargement : une ligne par réservation payée, triée par nom. */
  function listeEmargement(resas: any[], titreEvt: string) {
    const payees = resas
      .filter((r) => r.statut === 'payee')
      .sort((a, b) => a.nom.localeCompare(b.nom, 'fr'));

    const total = payees.reduce((s, r) => s + r.places, 0);
    const offerts = payees.filter((r) => r.benevole).reduce((s, r) => s + r.places, 0);

    const lignes: string[][] = [
      [`LISTE D'ÉMARGEMENT — ${titreEvt}`],
      [`${payees.length} réservations · ${total} personnes${offerts > 0 ? ` (dont ${offerts} bénévoles, repas offerts)` : ''}`],
      [`Éditée le ${new Date().toLocaleDateString('fr-FR')}`],
      [],
      ['Nom', 'Places', 'Code billet', 'Téléphone', 'Email', 'Remarque', 'Présent (à cocher)'],
      ...payees.map((r) => [
        r.nom, String(r.places), r.code_billet,
        r.telephone ?? '', r.email ?? '',
        [r.benevole ? 'Bénévole (offert)' : r.exposant ? 'Exposant' : '', r.commentaire ?? ''].filter(Boolean).join(' · '),
        '',
      ]),
      [],
      ['TOTAL', String(total), '', '', '', '', ''],
    ];

    telecharger(`emargement-${slugifie(titreEvt)}.csv`, lignes);
  }

  /**
   * Liste traiteur : repas à commander, par menu (détail des tarifs), payants et offerts aux bénévoles.
   * Places confirmées = payées + saisies à la main en attente de paiement. Les exposants ne comptent pas.
   */
  function listeTraiteur(resas: any[], titreEvt: string) {
    const comptees = resas.filter((r) =>
      !r.exposant && (r.statut === 'payee' || (r.statut === 'en_attente' && r.saisie_par)));
    const menus = new Map<string, { payants: number; offerts: number }>();
    const ajoute = (libelle: string, q: number, offert: boolean) => {
      const m = menus.get(libelle) ?? { payants: 0, offerts: 0 };
      if (offert) m.offerts += q; else m.payants += q;
      menus.set(libelle, m);
    };
    for (const r of comptees) {
      const detail: any[] = r.reservation_lignes ?? [];
      if (detail.length > 0) detail.forEach((l) => ajoute(l.libelle, l.quantite, !!r.benevole));
      else ajoute('Place', r.places, !!r.benevole);
    }
    const totPayants = [...menus.values()].reduce((s, m) => s + m.payants, 0);
    const totOfferts = [...menus.values()].reduce((s, m) => s + m.offerts, 0);

    const lignes: string[][] = [
      [`LISTE TRAITEUR — ${titreEvt}`],
      [`${totPayants + totOfferts} repas à prévoir · ${totPayants} payants · ${totOfferts} offerts aux bénévoles`],
      [`Éditée le ${new Date().toLocaleDateString('fr-FR')}`],
      [],
      ['Menu', 'Payants', 'Bénévoles (offerts)', 'Total'],
      ...[...menus.entries()].map(([libelle, m]) => [libelle, String(m.payants), String(m.offerts), String(m.payants + m.offerts)]),
      ['TOTAL', String(totPayants), String(totOfferts), String(totPayants + totOfferts)],
      [],
      ['Détail des bénévoles'],
      ['Nom', 'Repas', 'Détail', 'Remarque'],
      ...comptees.filter((r) => r.benevole).map((r) => [
        r.nom, String(r.places),
        (r.reservation_lignes ?? []).map((l: any) => `${l.quantite} x ${l.libelle}`).join(', '),
        r.commentaire ?? '',
      ]),
    ];
    telecharger(`traiteur-${slugifie(titreEvt)}.csv`, lignes);
  }

  /** Export comptable : toutes les réservations, tous statuts. */
  function exportComplet(resas: any[], nom: string) {
    const lignes: string[][] = [
      ['Référence', 'Type', 'Date réservation', 'Nom', 'Email', 'Téléphone',
       'Événement', 'Places', 'Montant €', 'Statut', 'Code billet',
       'Pointé', 'Paiement', 'Transaction SumUp', 'N° chèque', 'Détail', 'Remarque'],
      ...resas.map((r) => [
        r.reference,
        r.exposant ? 'Exposant' : r.benevole ? 'Bénévole' : 'Participant',
        new Date(r.created_at).toLocaleDateString('fr-FR'),
        r.nom, r.email ?? '', r.telephone ?? '',
        r.evenements?.titre ?? '',
        String(r.places),
        (r.montant_centimes / 100).toFixed(2).replace('.', ','),
        r.statut, r.code_billet,
        r.scanne_le ? 'oui' : 'non',
        r.benevole ? 'Offert' : r.mode_paiement === 'especes' ? 'Espèces' : r.mode_paiement === 'cheque' ? 'Chèque' : r.statut === 'payee' ? 'SumUp' : '',
        r.transaction_code ?? '',
        r.paiement_ref ?? '',
        (r.reservation_lignes ?? []).map((l: any) => `${l.quantite} x ${l.libelle}`).join(', '),
        r.commentaire ?? '',
      ]),
    ];
    telecharger(`reservations-${nom}.csv`, lignes);
  }

  const parEvenement = evenements
    .map((e) => ({
      ...e,
      resas: reservations.filter((r) => r.evenement_id === e.id),
    }))
    .filter((e) => e.resas.length > 0);

  return (
    <div className="export-zone">
      <button
        className="btn btn-k btn-sm"
        onClick={() => setOuvert(!ouvert)}
        disabled={reservations.length === 0}
      >
        Exporter ▾
      </button>

      {ouvert && (
        <div className="export-menu">
          <div className="export-titre">Liste d&apos;émargement</div>
          <p className="export-aide">
            Réservations payées uniquement, triées par nom, avec une colonne
            à cocher. À imprimer pour l&apos;entrée.
          </p>
          {parEvenement.map((e) => (
            <button
              key={e.id}
              className="export-item"
              onClick={() => { listeEmargement(e.resas, e.titre); setOuvert(false); }}
            >
              {e.titre}
              <span>{e.resas.filter((r) => r.statut === 'payee').length} payées</span>
            </button>
          ))}
          {parEvenement.length === 0 && (
            <p className="export-aide">Aucune réservation.</p>
          )}

          <div className="export-titre" style={{ marginTop: '1rem' }}>Liste traiteur</div>
          <p className="export-aide">
            Nombre de repas par menu à commander : places payées et à encaisser, plus les repas offerts aux bénévoles.
          </p>
          {parEvenement.map((e) => {
            const repas = e.resas
              .filter((r) => !r.exposant && (r.statut === 'payee' || (r.statut === 'en_attente' && r.saisie_par)))
              .reduce((s, r) => s + r.places, 0);
            return (
              <button
                key={`t-${e.id}`}
                className="export-item"
                onClick={() => { listeTraiteur(e.resas, e.titre); setOuvert(false); }}
              >
                {e.titre}
                <span>{repas} repas</span>
              </button>
            );
          })}

          <div className="export-titre" style={{ marginTop: '1rem' }}>
            Export comptable
          </div>
          <p className="export-aide">
            Toutes les réservations, tous statuts, avec le mode de paiement et les références SumUp.
          </p>
          <button
            className="export-item"
            onClick={() => { exportComplet(reservations, 'tous'); setOuvert(false); }}
          >
            Toutes les réservations
            <span>{reservations.length} lignes</span>
          </button>
          {parEvenement.map((e) => (
            <button
              key={`c-${e.id}`}
              className="export-item"
              onClick={() => { exportComplet(e.resas, slugifie(e.titre)); setOuvert(false); }}
            >
              {e.titre}
              <span>{e.resas.length} lignes</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
