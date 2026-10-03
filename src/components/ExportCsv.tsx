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

    const lignes: string[][] = [
      [`LISTE D'ÉMARGEMENT — ${titreEvt}`],
      [`${payees.length} réservations · ${total} personnes`],
      [`Éditée le ${new Date().toLocaleDateString('fr-FR')}`],
      [],
      ['Nom', 'Places', 'Code billet', 'Téléphone', 'Email', 'Remarque', 'Présent (à cocher)'],
      ...payees.map((r) => [
        r.nom, String(r.places), r.code_billet,
        r.telephone ?? '', r.email ?? '', r.commentaire ?? '', '',
      ]),
      [],
      ['TOTAL', String(total), '', '', '', '', ''],
    ];

    telecharger(`emargement-${slugifie(titreEvt)}.csv`, lignes);
  }

  /** Export comptable : toutes les réservations, tous statuts. */
  function exportComplet(resas: any[], nom: string) {
    const lignes: string[][] = [
      ['Référence', 'Date réservation', 'Nom', 'Email', 'Téléphone',
       'Événement', 'Places', 'Montant €', 'Statut', 'Code billet',
       'Pointé', 'Paiement', 'Transaction SumUp', 'N° chèque', 'Remarque'],
      ...resas.map((r) => [
        r.reference,
        new Date(r.created_at).toLocaleDateString('fr-FR'),
        r.nom, r.email ?? '', r.telephone ?? '',
        r.evenements?.titre ?? '',
        String(r.places),
        (r.montant_centimes / 100).toFixed(2).replace('.', ','),
        r.statut, r.code_billet,
        r.scanne_le ? 'oui' : 'non',
        r.mode_paiement === 'especes' ? 'Espèces' : r.mode_paiement === 'cheque' ? 'Chèque' : r.statut === 'payee' ? 'SumUp' : '',
        r.transaction_code ?? '',
        r.paiement_ref ?? '',
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
