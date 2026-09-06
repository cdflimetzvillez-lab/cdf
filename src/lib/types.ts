export type Saison = 'printemps' | 'ete' | 'automne' | 'hiver';

export interface SiteSettings {
  id: number;
  hero_kicker: string;
  hero_titre_1: string;
  hero_titre_accent: string;
  hero_titre_2: string;
  hero_texte: string;
  hero_couleur: string;
  logo_url: string | null;
  logo_blanc_url: string | null;
  email_contact: string;
  facebook_url: string | null;
  adresse: string;
  asso_titre: string;
  asso_texte: string;
  benevoles_titre: string;
  benevoles_texte: string;
}

export interface Stat { id: string; valeur: string; libelle: string; position: number; }

export interface Evenement {
  id: string;
  slug: string;
  titre: string;
  sous_titre: string | null;
  chapo: string | null;
  description: string | null;
  couleur: string;
  couleur_sombre: string;
  date_debut: string;
  date_fin: string | null;
  heure_debut: string | null;
  heure_fin: string | null;
  lieu: string | null;
  adresse: string | null;
  tarif: string;
  lien_reservation: string | null;
  libelle_reservation: string;
  billetterie_active: boolean;
  prix_centimes: number;
  places_max: number | null;
  places_par_reservation: number;
  cloture_reservations: string | null;
  saison: Saison;
  image_url: string | null;
  publie: boolean;
  position: number;
}

export interface Creneau {
  id: string; evenement_id: string; heure: string; titre: string;
  description: string | null; scene: string | null; position: number;
}

export interface InfoBloc {
  id: string; evenement_id: string; titre: string; lignes: string[]; position: number;
}

export interface FaqItem {
  id: string; evenement_id: string | null; question: string; reponse: string; position: number;
}

export interface Demande {
  id: string; evenement_id: string | null; nom: string; email: string;
  telephone: string | null; type: string; message: string | null;
  statut: 'nouveau' | 'traite' | 'refuse'; created_at: string;
}

export interface Reservation {
  id: string;
  evenement_id: string;
  nom: string;
  email: string;
  telephone: string | null;
  commentaire: string | null;
  places: number;
  montant_centimes: number;
  reference: string;
  checkout_id: string | null;
  transaction_code: string | null;
  statut: 'en_attente' | 'payee' | 'echouee' | 'expiree' | 'remboursee' | 'annulee';
  paye_le: string | null;
  code_billet: string;
  scanne_le: string | null;
  created_at: string;
}

export type Partenaire = {
  id: string;
  nom: string;
  logo_url: string;
  site_url: string | null;
  actif: boolean;
  position: number;
};
