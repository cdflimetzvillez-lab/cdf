export type ConfigRoue = {
  titre: string;
  accroche: string;
  periode_texte: string;
  participations_par_jour: number;
  taux_gain: number;            // pourcentage de tours gagnants (0-100)
  message_gagne: string;
  message_perdu: string;
};

export type ModuleAccueil = {
  id: string;
  module_key: string;
  is_active: boolean;
  start_date: string | null;
  end_date: string | null;
  config: Partial<ConfigRoue>;
  updated_at: string;
};

export type LotRoue = {
  id: string;
  nom: string;
  description: string | null;
  stock: number;
  poids: number;
  actif: boolean;
  position: number;
};

export type ParticipationRoue = {
  id: string;
  joueur_id: string;
  jour: string;
  gagne: boolean;
  lot_id: string | null;
  code: string | null;
  prenom: string | null;
  nom: string | null;
  email: string | null;
  telephone: string | null;
  reclame_le: string | null;
  retire_le: string | null;
  created_at: string;
  roue_lots?: { nom: string } | null;
};

export type StatsRoue = {
  participations: number;
  joueurs_uniques: number;
  gagnants: number;
  perdants: number;
  lots_disponibles: number;
};

export const CONFIG_DEFAUT: ConfigRoue = {
  titre: 'La Roue de la Rentrée',
  accroche: 'La rentrée aussi se fête à Limetz-Villez !',
  periode_texte: 'Du 7 au 20 septembre',
  participations_par_jour: 1,
  taux_gain: 12,
  message_gagne: 'Présentez votre code au stand du Comité des Fêtes pour récupérer votre lot.',
  message_perdu: 'Pas de chance aujourd’hui… revenez demain tenter votre chance !',
};

/** Segments de la roue : 12 cases, 3 « dorées » (visuel gagnant). Aucun texte. */
export const NB_SEGMENTS = 12;
export const SEGMENTS_GAGNANTS = [1, 5, 9];
