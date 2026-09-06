/** Types du module « Les Trésors de Noël » — miroir des tables tdn_* */

export type Categorie = 'adulte' | 'enfant';

export type Reglages = {
  id: 1;
  titre: string;
  accroche: string;
  periode_texte: string;
  marche_texte: string;
  duree_texte: string;
  tarif_adulte_centimes: number;
  tarif_enfant_centimes: number;
  inscriptions_ouvertes: boolean;
  jeu_actif: boolean;
  places_max: number;
  jeu_debut: string | null;
  jeu_fin: string | null;
  grand_tresor_montant: string;
  grand_tresor_texte: string;
  lieu_revelation: string;
  tirage_cle_id: string | null;
  tirage_le: string | null;
};

export type Partenaire = { id: string; nom: string; type: string | null };

export type Lot = {
  id: string;
  nom: string;
  valeur: string | null;
  partenaire_id: string | null;
  stock: number;
  grand: boolean;
  position: number;
  /** Jointure éventuelle */
  tdn_partenaires?: { nom: string } | null;
};

export type Bloc =
  | { type: 'texte'; contenu: string }
  | { type: 'image'; src: string; alt: string; legende?: string }
  | { type: 'audio'; titre: string; duree: string }
  | { type: 'video'; titre: string; duree: string };

export type QuestionType = 'texte' | 'code' | 'choix';

export type Mission = {
  id: string;
  numero: number;
  titre: string;
  lieu: string | null;
  accroche: string | null;
  blocs: Bloc[];
  question_type: QuestionType;
  intitule: string;
  reponses: string[];
  options: string[];
  bonne_reponse: number | null;
  longueur: number | null;
  placeholder: string | null;
  indices: string[];
  solution_secours: string | null;
  publie: boolean;
};

/** Mission telle qu'envoyée au navigateur : sans les réponses. */
export type MissionPublique = Omit<Mission, 'reponses' | 'bonne_reponse'>;

export type Compte = {
  id: string;
  token: string;
  prenom: string;
  nom: string;
  email: string;
  telephone: string | null;
};

export type Participant = {
  id: string;
  compte_id: string;
  prenom: string;
  categorie: Categorie;
  paye: boolean;
};

export type Cle = {
  id: string;
  participant_id: string;
  numero: number;
  code: string;
  lot_id: string | null;
  revelee_le: string | null;
};

export type Commande = {
  id: string;
  compte_id: string;
  reference: string;
  checkout_id: string | null;
  montant_centimes: number;
  participant_ids: string[];
  statut: 'en_attente' | 'payee' | 'echouee' | 'expiree';
  paye_le: string | null;
};

export type Stats = {
  inscrits: number;
  ca_centimes: number;
  commences: number;
  termines: number;
  cles_generees: number;
  cles_revelees: number;
};

/** Progression d'un participant, calculée côté serveur. */
export type Progression = {
  participant: Participant;
  missionsValidees: string[];   // ids de missions
  cle: Cle | null;
};

export const numeroCle = (n: number) => String(n).padStart(3, '0');
