/** Modules du back-office : clé, libellé du menu, chemin et catégorie. */
export const MODULES = [
  { cle: 'tableau',      libelle: 'Tableau de bord',       chemin: '/admin',              categorie: 'general' },
  { cle: 'evenements',   libelle: 'Événements',            chemin: '/admin/evenements',   categorie: 'evenements' },
  { cle: 'reservations', libelle: 'Réservations',          chemin: '/admin/reservations', categorie: 'evenements' },
  { cle: 'demandes',     libelle: 'Demandes reçues',       chemin: '/admin/demandes',     categorie: 'evenements' },
  { cle: 'tresorerie',   libelle: 'Trésorerie',            chemin: '/admin/tresorerie',   categorie: 'finances' },
  { cle: 'compta',       libelle: 'Comptabilité',          chemin: '/admin/compta',       categorie: 'finances' },
  { cle: 'tresors',      libelle: 'Trésors de Noël',       chemin: '/admin/tresors',      categorie: 'animations' },
  { cle: 'pere-noel',    libelle: 'Père Noël vidéo',       chemin: '/admin/pere-noel',    categorie: 'animations' },
  { cle: 'roue',         libelle: 'Roue de la Rentrée',    chemin: '/admin/roue',         categorie: 'animations' },
  { cle: 'theme',        libelle: 'Thème de l\u2019accueil', chemin: '/admin/theme',      categorie: 'site' },
  { cle: 'partenaires',  libelle: 'Partenaires',           chemin: '/admin/partenaires',  categorie: 'site' },
  { cle: 'association',  libelle: 'Association',           chemin: '/admin/association',  categorie: 'site' },
  { cle: 'parametres',   libelle: 'Réglages du site',      chemin: '/admin/parametres',   categorie: 'site' },
  { cle: 'maintenance',  libelle: 'Maintenance',           chemin: '/admin/maintenance',  categorie: 'site' },
  // Réservé aux administrateurs : ne peut pas être confié à un poste.
  { cle: 'bureau',       libelle: 'Accès du bureau',       chemin: '/admin/bureau',       categorie: 'bureau' },
] as const;

export type ModuleCle = (typeof MODULES)[number]['cle'];

export const CATEGORIES: { cle: string; libelle: string }[] = [
  { cle: 'general', libelle: '' },
  { cle: 'evenements', libelle: 'Événements' },
  { cle: 'finances', libelle: 'Finances' },
  { cle: 'animations', libelle: 'Animations' },
  { cle: 'site', libelle: 'Site' },
  { cle: 'bureau', libelle: 'Bureau' },
];

/** Modules qu'un administrateur peut confier à un poste. */
export const MODULES_ATTRIBUABLES = MODULES.filter((m) => m.cle !== 'bureau');
export const TOUS_LES_MODULES: ModuleCle[] = MODULES.map((m) => m.cle);

/** Chemins rattachés à un autre module que celui de leur préfixe. */
const CHEMINS_ANNEXES: { prefixe: string; cle: ModuleCle }[] = [
  { prefixe: '/admin/pointage', cle: 'reservations' },
];

/** Module dont dépend une page de l'admin, d'après son chemin. null si la page est inconnue. */
export function moduleDuChemin(chemin: string): ModuleCle | null {
  if (chemin === '/admin' || chemin === '/admin/') return 'tableau';
  const annexe = CHEMINS_ANNEXES.find((a) => chemin.startsWith(a.prefixe));
  if (annexe) return annexe.cle;
  const trouve = MODULES.find((m) => m.chemin !== '/admin' && (chemin === m.chemin || chemin.startsWith(`${m.chemin}/`)));
  return trouve?.cle ?? null;
}

/** Première page accessible, pour rediriger un membre qui n'a pas accès à la page demandée. */
export function premiereChemin(modules: readonly string[]): string | null {
  return MODULES.find((m) => modules.includes(m.cle))?.chemin ?? null;
}

/** Les deux modules dont les données sont protégées en base par is_staff(). */
export const MODULES_FINANCES: ModuleCle[] = ['tresorerie', 'compta'];
