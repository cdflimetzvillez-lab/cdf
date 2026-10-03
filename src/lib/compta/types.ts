export type TypeCompte = 'bilan' | 'tresorerie' | 'charge' | 'produit';

export interface Exercice {
  id: string;
  libelle: string;
  date_debut: string;
  date_fin: string;
  cloture: boolean;
  cloture_le: string | null;
}

export interface Compte {
  numero: string;
  intitule: string;
  type: TypeCompte;
  actif: boolean;
}

export interface Journal {
  code: string;
  libelle: string;
  compte_tresorerie: string | null;
}

export interface EvenementCompta {
  id: string;
  code: string;
  libelle: string;
  date_evenement: string | null;
  statut: 'a_venir' | 'en_cours' | 'termine';
}

/** Une ligne de la vue compta_v_lignes (journaux, grand livre). */
export interface LigneVue {
  id: string;
  ecriture_id: string;
  exercice_id: string;
  journal_code: string;
  numero: number;
  piece: string;
  date_piece: string;
  libelle: string;
  position: number;
  compte_numero: string;
  compte_intitule: string;
  compte_type: TypeCompte;
  compta_evenement_id: string | null;
  evenement_code: string | null;
  debit_centimes: number;
  credit_centimes: number;
  pointe_le: string | null;
  source: 'manuel' | 'site' | 'annulation';
  contrepassee_par: string | null;
  justificatif_chemin: string | null;
  cree_par_nom: string | null;
  created_at: string;
}

/** Une ligne de la vue compta_v_balance. */
export interface LigneBalance {
  exercice_id: string;
  numero: string;
  intitule: string;
  type: TypeCompte;
  debit_centimes: number;
  credit_centimes: number;
  solde_centimes: number;
}

/** Ligne envoyée à la fonction compta_saisir_ecriture (montants en centimes). */
export interface LigneSaisie {
  compte: string;
  debit: number;
  credit: number;
  evenement_id?: string | null;
  libelle?: string | null;
}

export type Retour = { ok?: string; erreur?: string; id?: string } | null;

export const LIBELLE_TYPE: Record<TypeCompte, string> = {
  bilan: 'Bilan',
  tresorerie: 'Trésorerie',
  charge: 'Charge',
  produit: 'Produit',
};

export const LIBELLE_STATUT_EVT: Record<EvenementCompta['statut'], string> = {
  a_venir: 'À venir',
  en_cours: 'En cours',
  termine: 'Terminé',
};
