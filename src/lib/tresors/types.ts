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
  /** Montant unitaire affiché d'un lot du grand trésor, ex. « 100 € ». */
  grand_tresor_montant: string;
  grand_tresor_texte: string;
  /** Nombre de lots du grand trésor. Pour l'affichage public, il est recalculé d'après le stock des lots marqués « grand ». */
  grand_tresor_nombre: number;
  lieu_revelation: string;
  /** Colonnes de l'ancien tirage séparé du grand trésor : plus utilisées (tirage unique à la révélation). */
  tirage_cle_id: string | null;
  tirage_cle_ids: string[] | null;
  tirage_le: string | null;
  module_actif: boolean;
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

/* ---------- Grand trésor : plusieurs lots identiques, mêlés aux autres lots à la révélation ---------- */

/** Nombre de lots du grand trésor (1 au minimum, même si la colonne n'existe pas encore en base). */
export const nombreGrandTresor = (r: { grand_tresor_nombre?: number | null }) => Math.max(1, Math.floor(Number(r.grand_tresor_nombre)) || 1);

/** Montant affiché : « 3 × 100 € » s'il y a plusieurs lots, « 100 € » sinon (espaces insécables). */
export const montantGrandTresor = (r: { grand_tresor_nombre?: number | null; grand_tresor_montant: string }) => {
  const n = nombreGrandTresor(r);
  const unitaire = (r.grand_tresor_montant ?? '').replace(/ /g, '\u00a0');
  return n > 1 ? `${n}\u00a0×\u00a0${unitaire}` : unitaire;
};

const NOMBRES = ['zéro', 'une', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix'];
/** Petit nombre en toutes lettres, accordé au féminin (« une carte », « trois clés »). */
export const enLettres = (n: number) => NOMBRES[n] ?? String(n);
