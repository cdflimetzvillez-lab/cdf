import { texteSur } from '@/lib/format';

export type MotifTheme = 'ruban' | 'flocons' | 'etoile' | 'aucun';

/** Un thème d'habillage de la page d'accueil, affiché entre deux dates. */
export interface ThemeAccueil {
  id: string;
  nom: string;
  /** Couleur du haut de page, au format #RRGGBB. */
  couleur: string;
  motif: MotifTheme;
  /** Étiquette noire au-dessus du titre. */
  etiquette: string;
  /** Message ajouté au bandeau défilant. */
  bandeau: string;
  /** Bloc de message sous le bandeau (facultatif). */
  titre: string;
  texte: string;
  bouton: string;
  lien: string;
  /** Dates incluses, au format AAAA-MM-JJ. */
  debut: string;
  fin: string;
  actif: boolean;
}

export const MOTIFS: Record<MotifTheme, string> = {
  ruban: 'Ruban',
  flocons: 'Flocons',
  etoile: 'Étoile',
  aucun: 'Aucun',
};

type Modele = Omit<ThemeAccueil, 'id' | 'debut' | 'fin' | 'actif'> & { du: string; au: string };

/** Thèmes prêts à l'emploi : ils pré-remplissent le formulaire, tout reste modifiable. */
export const MODELES: Record<string, Modele> = {
  'octobre-rose': {
    nom: 'Octobre Rose', couleur: '#F591BC', motif: 'ruban',
    etiquette: 'Octobre Rose · Limetz-Villez',
    bandeau: 'Octobre Rose · Le village se met au rose',
    titre: 'En octobre, le village se met au rose',
    texte: 'Le Comité des Fêtes s\u2019associe à Octobre Rose, le mois de sensibilisation au dépistage du cancer du sein.',
    bouton: 'En savoir plus', lien: '', du: '10-01', au: '10-31',
  },
  movember: {
    nom: 'Movember', couleur: '#2F6FD0', motif: 'etoile',
    etiquette: 'Movember · Limetz-Villez',
    bandeau: 'Movember · Le village se mobilise',
    titre: 'En novembre, on en parle',
    texte: 'Le Comité des Fêtes relaie Movember, le mois de sensibilisation à la santé masculine.',
    bouton: 'En savoir plus', lien: '', du: '11-01', au: '11-30',
  },
  telethon: {
    nom: 'Téléthon', couleur: '#F7B500', motif: 'etoile',
    etiquette: 'Téléthon · Limetz-Villez',
    bandeau: 'Téléthon · Le village se mobilise',
    titre: 'Le village se mobilise pour le Téléthon',
    texte: 'Retrouvez les animations organisées au profit du Téléthon.',
    bouton: 'En savoir plus', lien: '', du: '12-01', au: '12-07',
  },
  noel: {
    nom: 'Noël', couleur: '#C8102E', motif: 'flocons',
    etiquette: 'Noël au village · Limetz-Villez',
    bandeau: 'Joyeux Noël',
    titre: '', texte: '', bouton: '', lien: '', du: '12-08', au: '12-26',
  },
  'fete-nationale': {
    nom: 'Fête nationale', couleur: '#1F4FA8', motif: 'etoile',
    etiquette: '14 juillet · Limetz-Villez',
    bandeau: 'Bonne fête nationale',
    titre: '', texte: '', bouton: '', lien: '', du: '07-10', au: '07-14',
  },
};

export const COULEUR_VALIDE = /^#[0-9a-fA-F]{6}$/;

/** Date du jour à Paris, au format AAAA-MM-JJ. */
export function jourParis(maintenant = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris' }).format(maintenant);
}

export type EtatTheme = 'en_ligne' | 'programme' | 'passe' | 'desactive';

export function etatTheme(t: ThemeAccueil, jour = jourParis()): EtatTheme {
  if (!t.actif) return 'desactive';
  if (jour < t.debut) return 'programme';
  if (jour > t.fin) return 'passe';
  return 'en_ligne';
}

/** Thème à afficher aujourd'hui : actif et dans sa période. Le plus récemment commencé l'emporte. */
export function themeDuJour(themes: ThemeAccueil[], jour = jourParis()): ThemeAccueil | null {
  return (
    themes
      .filter((t) => etatTheme(t, jour) === 'en_ligne' && COULEUR_VALIDE.test(t.couleur))
      .sort((a, b) => b.debut.localeCompare(a.debut))[0] ?? null
  );
}

/** Version foncée et saturée d'une couleur (#RRGGBB), pour un titre lisible sur fond clair. */
export function foncer(hex: string): string {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  let h = 0;
  if (d > 0) {
    if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
  }
  h = Math.round(h * 60 + 360) % 360;
  const l0 = (max + min) / 2;
  const s0 = d === 0 ? 0 : d / (1 - Math.abs(2 * l0 - 1));
  // Même teinte, saturation soutenue, luminosité ramenée à 38 %.
  return `hsl(${h} ${Math.round(Math.max(s0, 0.7) * 100)}% 38%)`;
}

/**
 * Variables CSS de l'habillage, déduites de la couleur du thème :
 * texte clair ou foncé selon le fond, accents et rayons assortis.
 */
export function variablesTheme(t: ThemeAccueil): Record<string, string> {
  const fondClair = texteSur(t.couleur) === '#141014';
  return {
    '--evt': t.couleur,
    '--th': t.couleur,
    '--th-texte': fondClair ? '#141014' : '#FFF8EC',
    '--th-a1': fondClair ? '#FFFFFF' : '#FFD400',
    '--th-a2': fondClair ? foncer(t.couleur) : '#FFFFFF',
    '--th-rayon': fondClair ? 'rgba(255,255,255,.55)' : 'rgba(255,255,255,.2)',
    '--th-clair': `color-mix(in srgb, ${t.couleur} 45%, #ffffff)`,
    '--th-pale': `color-mix(in srgb, ${t.couleur} 16%, #ffffff)`,
  };
}

/** Date AAAA-MM-JJ -> « 1er octobre », « 31 octobre ». */
export function dateTheme(iso: string): string {
  const MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  const [a, m, j] = iso.split('-').map(Number);
  if (!a || !m || !j) return iso;
  return `${j === 1 ? '1er' : j} ${MOIS[m - 1]} ${a}`;
}
