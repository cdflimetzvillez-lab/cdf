export type Sagesse = 'presque' | 'tres_sage' | 'le_plus_sage';
export type TonSecret = 'rigolo' | 'tendre' | 'serieux';
export type StatutPaiement = 'en_attente' | 'payee' | 'echouee' | 'expiree';
export type StatutGeneration = 'a_faire' | 'relecture' | 'audio' | 'video' | 'terminee' | 'erreur';

export interface ReglagesPn {
  id: 1;
  module_actif: boolean;
  commandes_ouvertes: boolean;
  titre: string;
  accroche: string;
  prix_centimes: number;
  delai_texte: string;
  generation_auto: boolean;
  relecture_script: boolean;
  image_url: string | null;
  video_demo_url: string | null;
  voice_id: string | null;
  modele_voix: string;
  stabilite: number;
  similarite: number;
  style_voix: number;
  vitesse: number;
  expressivite: 'low' | 'medium' | 'high';
  motion_prompt: string;
  duree_cible_sec: number;
  consignes_script: string;
}

export interface CommandePn {
  id: string;
  created_at: string;
  reference: string;
  token: string;
  test: boolean;
  parent_prenom: string;
  email: string;
  enfant_prenom: string;
  prononciation: string | null;
  age: number | null;
  genre: 'fille' | 'garcon' | null;
  sagesse: Sagesse;
  lettre: string | null;
  cadeaux: string | null;
  fierte: string | null;
  passion: string | null;
  effort: string | null;
  salut: string | null;
  secret: string | null;
  ton_secret: TonSecret;
  montant_centimes: number;
  checkout_id: string | null;
  statut: StatutPaiement;
  transaction_code: string | null;
  paye_le: string | null;
  gen_statut: StatutGeneration;
  script: string | null;
  lettre_reponse: string | null;
  certificat_mention: string | null;
  audio_url: string | null;
  heygen_video_id: string | null;
  video_url: string | null;
  duree_sec: number | null;
  erreur: string | null;
  livre_le: string | null;
  email_envoye: boolean;
}

export interface StatsPn {
  commandes: number;
  ca_centimes: number;
  a_generer: number;
  a_relire: number;
  en_cours: number;
  livrees: number;
  en_erreur: number;
  secondes_video: number;
}

export const LIBELLE_SAGESSE: Record<Sagesse, string> = {
  presque: 'presque sage',
  tres_sage: 'très sage',
  le_plus_sage: 'le plus sage du monde',
};

export const LIBELLE_GEN: Record<StatutGeneration, string> = {
  a_faire: 'À générer',
  relecture: 'Script à relire',
  audio: 'Audio en cours',
  video: 'Vidéo en cours',
  terminee: 'Livrée',
  erreur: 'Erreur',
};

/** Coût HeyGen Avatar IV : 0,05 $ la seconde. Affiché à titre indicatif. */
export const COUT_HEYGEN_USD_PAR_SEC = 0.05;
