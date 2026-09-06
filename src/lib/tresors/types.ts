/** Types du module « Les Trésors de Noël ». Pensés pour être mappés 1:1 sur des tables Supabase. */

export type Categorie = 'adulte' | 'enfant';

export type Participant = {
  id: string;
  prenom: string;
  categorie: Categorie;
  inscrit: boolean;
};

export type Compte = {
  id: string;
  nom: string;
  prenom: string;
  email: string;
  telephone: string;
  participants: Participant[];
};

export type Cle = {
  numero: string;   // « 084 »
  code: string;     // « NOEL-8K4P »
  participantId: string;
  revelee: boolean;
  lotId?: string;
};

export type Progression = {
  participantId: string;
  missionsValidees: number[];
  cle?: Cle;
};

/** Contenu libre d'une mission : texte, image, audio fictif, vidéo fictive. */
export type Bloc =
  | { type: 'texte'; contenu: string }
  | { type: 'image'; src: string; alt: string; legende?: string }
  | { type: 'audio'; titre: string; duree: string }
  | { type: 'video'; titre: string; duree: string };

export type Question =
  | { type: 'texte'; intitule: string; reponses: string[]; placeholder?: string }
  | { type: 'code'; intitule: string; reponses: string[]; longueur: number }
  | { type: 'choix'; intitule: string; options: string[]; bonneReponse: number };

export type Mission = {
  numero: number;
  titre: string;
  lieu: string;
  accroche: string;
  blocs: Bloc[];
  question: Question;
  indices: string[];
  solutionSecours?: string;
};

export type Lot = {
  id: string;
  nom: string;
  valeur: string;
  partenaire: string;
  stock: number;
  attribues: number;
  reveles: number;
  grand?: boolean;
};

export type Partenaire = { id: string; nom: string; type: string; lots: number };

export type StatsAdmin = {
  inscrits: number;
  ca: number;
  commences: number;
  termines: number;
  clesGenerees: number;
  clesRevelees: number;
};
