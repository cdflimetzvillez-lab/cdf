#!/usr/bin/env bash
# Thème de la page d'accueil (Octobre Rose, Noël...) : habillage programmé entre deux dates.
# À exécuter à la racine du projet :  bash install-theme-accueil.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d "src/app/admin/(protected)/compta" ]; then
  echo "Lance ce script à la racine du repo (module comptabilité déjà installé)."; exit 1
fi
echo "Installation du thème de la page d'accueil…"
mkdir -p 'src/lib/theme'
cat > 'src/lib/theme/types.ts' <<'EOF_THEME_FICHIER'
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
EOF_THEME_FICHIER
echo "  ✓ src/lib/theme/types.ts"
mkdir -p 'src/lib/theme'
cat > 'src/lib/theme/db.ts' <<'EOF_THEME_FICHIER'
import 'server-only';
import { createAdminClient } from '@/lib/supabase/admin';
import type { ThemeAccueil } from './types';

/** Les thèmes sont rangés dans homepage_modules, comme la Roue de la Rentrée. */
export const CLE_MODULE = 'theme_accueil';

export async function getThemes(): Promise<ThemeAccueil[]> {
  try {
    const { data } = await createAdminClient()
      .from('homepage_modules').select('config').eq('module_key', CLE_MODULE).maybeSingle();
    const themes = (data?.config as { themes?: ThemeAccueil[] } | null)?.themes;
    return Array.isArray(themes) ? themes : [];
  } catch {
    // Un souci de lecture ne doit jamais empêcher la page d'accueil de s'afficher.
    return [];
  }
}
EOF_THEME_FICHIER
echo "  ✓ src/lib/theme/db.ts"
mkdir -p 'src/app'
cat > 'src/app/theme-actions.ts' <<'EOF_THEME_FICHIER'
'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { CLE_MODULE, getThemes } from '@/lib/theme/db';
import { COULEUR_VALIDE, MOTIFS, type MotifTheme, type ThemeAccueil } from '@/lib/theme/types';

export type EtatThemeForm = { ok?: string; erreur?: string } | null;

const DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Enregistre la liste complète des thèmes (la ligne du module est créée au premier usage). */
async function ecrire(themes: ThemeAccueil[]): Promise<string | null> {
  const db = createAdminClient();
  const { data: ligne } = await db.from('homepage_modules').select('id').eq('module_key', CLE_MODULE).maybeSingle();
  const { error } = ligne
    ? await db.from('homepage_modules').update({ config: { themes } }).eq('id', ligne.id)
    : await db.from('homepage_modules').insert({ module_key: CLE_MODULE, is_active: true, config: { themes } });
  if (error) return error.message;
  revalidatePath('/');
  revalidatePath('/admin/theme');
  return null;
}

/** Ajoute un thème ou modifie celui dont l'identifiant est fourni. */
export async function enregistrerTheme(_prev: EtatThemeForm, fd: FormData): Promise<EtatThemeForm> {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const texte = (cle: string, max: number) => String(fd.get(cle) ?? '').trim().slice(0, max);
  const id = texte('id', 60);
  const theme: ThemeAccueil = {
    id: id || `t-${Date.now().toString(36)}`,
    nom: texte('nom', 40),
    couleur: texte('couleur', 7),
    motif: (texte('motif', 10) in MOTIFS ? texte('motif', 10) : 'aucun') as MotifTheme,
    etiquette: texte('etiquette', 60),
    bandeau: texte('bandeau', 80),
    titre: texte('titre', 90),
    texte: texte('texte', 400),
    bouton: texte('bouton', 30),
    lien: texte('lien', 300),
    debut: texte('debut', 10),
    fin: texte('fin', 10),
    actif: fd.get('actif') === 'on',
  };

  if (theme.nom.length < 2) return { erreur: 'Le nom du thème est obligatoire.' };
  if (!COULEUR_VALIDE.test(theme.couleur)) return { erreur: 'Couleur invalide : format attendu #RRGGBB.' };
  if (!DATE.test(theme.debut) || !DATE.test(theme.fin)) return { erreur: 'Les deux dates sont obligatoires.' };
  if (theme.fin < theme.debut) return { erreur: 'La date de fin est avant la date de début.' };
  if (theme.lien && !/^(https?:\/\/|\/)/.test(theme.lien)) {
    return { erreur: 'Le lien doit commencer par https:// ou par / pour une page du site.' };
  }

  const themes = await getThemes();
  const suite = themes.some((t) => t.id === theme.id)
    ? themes.map((t) => (t.id === theme.id ? theme : t))
    : [...themes, theme];
  suite.sort((a, b) => a.debut.localeCompare(b.debut));

  const erreur = await ecrire(suite);
  if (erreur) return { erreur };
  return { ok: id ? `Thème « ${theme.nom} » modifié.` : `Thème « ${theme.nom} » ajouté.` };
}

export async function basculerTheme(id: string, actif: boolean): Promise<EtatThemeForm> {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const themes = await getThemes();
  const erreur = await ecrire(themes.map((t) => (t.id === id ? { ...t, actif } : t)));
  return erreur ? { erreur } : { ok: actif ? 'Thème activé.' : 'Thème désactivé.' };
}

export async function supprimerTheme(id: string): Promise<EtatThemeForm> {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const themes = await getThemes();
  const erreur = await ecrire(themes.filter((t) => t.id !== id));
  return erreur ? { erreur } : { ok: 'Thème supprimé.' };
}
EOF_THEME_FICHIER
echo "  ✓ src/app/theme-actions.ts"
mkdir -p 'src/components/theme'
cat > 'src/components/theme/theme.css' <<'EOF_THEME_FICHIER'
/* Habillage de la page d'accueil par un thème (Octobre Rose, Noël...). */

/* ---------- Haut de page ---------- */
.hero.th::before{background:repeating-conic-gradient(from 0deg at 50% 42%,
  var(--th-rayon) 0deg 7deg, transparent 7deg 14deg);}
.hero.th h1 .jaune{color:var(--th-a1);}
.hero.th h1 .cyan{color:var(--th-a2);}
.hero.th .hero-tag,.hero.th .scroll-hint{color:var(--th-texte);}
.hero.th .kicker{color:var(--th-clair);}

.th-pastille{position:absolute;top:0;right:0;z-index:4;display:flex;align-items:center;gap:.6rem;
  background:var(--creme);color:var(--noir);border:3px solid var(--noir);box-shadow:5px 5px 0 var(--noir);
  padding:.55rem .9rem;transform:rotate(4deg);text-align:left;}
.th-pastille b{font-family:'Anton',sans-serif;font-weight:400;text-transform:uppercase;
  font-size:1.15rem;line-height:.95;max-width:9ch;}
.th-motif{flex:none;width:30px;height:46px;}
.th-etoile{flex:none;font-size:2.1rem;line-height:1;color:var(--th);}

.th-neige{position:absolute;inset:0;z-index:2;pointer-events:none;opacity:.9;
  background-image:radial-gradient(#fff 2px,transparent 2.5px),radial-gradient(#fff 1.5px,transparent 2px),
    radial-gradient(#fff 3px,transparent 3.5px);
  background-size:90px 110px,60px 70px,150px 130px;background-position:10px 20px,40px 60px,70px 10px;}

/* ---------- Bandeau défilant ---------- */
.th-bandeau .marquee{color:var(--th-clair);border-color:var(--th);}
.th-bandeau .marquee span::after{color:#fff;}

/* ---------- Bloc de message ---------- */
.th-bloc{padding:2.6rem 2rem;background:var(--th-pale);border-bottom:3px solid var(--noir);}
.th-bloc-in{max-width:820px;margin:0 auto;display:flex;gap:1.4rem;align-items:flex-start;}
.th-bloc .th-motif{width:46px;height:70px;}
.th-bloc .th-etoile{font-size:3rem;}
.th-bloc h2{font-size:clamp(1.7rem,4.4vw,2.6rem);line-height:.98;margin-bottom:.7rem;}
.th-bloc p{font-size:1.02rem;line-height:1.55;max-width:58ch;margin-bottom:1.2rem;}
.th-bloc p:last-child{margin-bottom:0;}

@media (max-width:760px){
  /* Sur mobile, la pastille se place sous le logo au lieu du coin. */
  .th-pastille{position:relative;display:inline-flex;margin:0 auto 1.6rem;}
  .th-bloc{padding:2rem 1.2rem;}
  .th-bloc-in{flex-direction:column;gap:.8rem;}
}

/* ---------- Aperçu dans l'admin ---------- */
.th-apercu{border:3px solid var(--noir);overflow:hidden;background:var(--creme);}
.th-apercu-hero{position:relative;background:var(--th);padding:1.6rem 1rem 2rem;text-align:center;overflow:hidden;}
.th-apercu-hero::before{content:"";position:absolute;inset:-60% -30%;
  background:repeating-conic-gradient(from 0deg at 50% 42%,var(--th-rayon) 0deg 7deg,transparent 7deg 14deg);}
.th-apercu-hero > *{position:relative;z-index:3;}
.th-apercu-hero .th-neige{position:absolute;z-index:2;}
.th-apercu-hero .th-pastille{position:relative;display:inline-flex;margin-bottom:1rem;}
.th-apercu-hero .kicker{color:var(--th-clair);font-size:.62rem;}
.th-apercu-hero h3{font-size:clamp(1.8rem,6vw,3rem);line-height:.88;color:var(--creme);
  text-shadow:4px 4px 0 var(--noir);margin-top:1rem;}
.th-apercu-hero h3 .a1{color:var(--th-a1);}
.th-apercu-hero h3 .a2{color:var(--th-a2);}
.th-apercu .marquee div{animation:none;font-size:.9rem;padding:.5rem 0;}
.th-apercu .th-bloc{padding:1.2rem 1rem;}
.th-apercu .th-bloc h2{font-size:1.3rem;}
.th-apercu .th-bloc p{font-size:.9rem;}
.th-pt{display:inline-block;width:22px;height:22px;border:2px solid var(--noir);vertical-align:middle;}
EOF_THEME_FICHIER
echo "  ✓ src/components/theme/theme.css"
mkdir -p 'src/components/theme'
cat > 'src/components/theme/ThemeAccueil.tsx' <<'EOF_THEME_FICHIER'
import type { ThemeAccueil } from '@/lib/theme/types';
import './theme.css';

/** Motif du thème : ruban de sensibilisation ou étoile. Les flocons sont un fond, voir Neige. */
export function Motif({ theme }: { theme: ThemeAccueil }) {
  if (theme.motif === 'ruban') {
    const trace = 'M13 86 L40 32 C47 17 40 8 30 8 C20 8 13 17 20 32 L47 86';
    return (
      <svg className="th-motif" viewBox="0 0 60 92" aria-hidden="true" focusable="false">
        <path d={trace} fill="none" stroke="#141014" strokeWidth="17" strokeLinejoin="round" />
        <path d={trace} fill="none" stroke={theme.couleur} strokeWidth="10" strokeLinejoin="round" />
      </svg>
    );
  }
  if (theme.motif === 'etoile' || theme.motif === 'flocons') {
    return <span className="th-etoile" aria-hidden="true">✷</span>;
  }
  return null;
}

/** Fond de flocons du haut de page. */
export function Neige({ theme }: { theme: ThemeAccueil }) {
  return theme.motif === 'flocons' ? <div className="th-neige" aria-hidden="true" /> : null;
}

/** Pastille inclinée portant le nom du thème. */
export function PastilleTheme({ theme }: { theme: ThemeAccueil }) {
  return (
    <div className="th-pastille">
      <Motif theme={theme} />
      <b>{theme.nom}</b>
    </div>
  );
}

/** Bloc de message sous le bandeau défilant. Rien n'est affiché sans titre ni texte. */
export function BlocTheme({ theme, style }: { theme: ThemeAccueil; style?: React.CSSProperties }) {
  if (!theme.titre && !theme.texte) return null;
  const externe = /^https?:\/\//.test(theme.lien);
  return (
    <section className="th-bloc" style={style} aria-label={theme.nom}>
      <div className="th-bloc-in">
        <Motif theme={theme} />
        <div>
          {theme.titre && <h2>{theme.titre}</h2>}
          {theme.texte && <p>{theme.texte}</p>}
          {theme.lien && (
            <a className="btn btn-k" href={theme.lien} {...(externe ? { target: '_blank', rel: 'noreferrer' } : {})}>
              {theme.bouton || 'En savoir plus'}
            </a>
          )}
        </div>
      </div>
    </section>
  );
}
EOF_THEME_FICHIER
echo "  ✓ src/components/theme/ThemeAccueil.tsx"
mkdir -p 'src/components/theme'
cat > 'src/components/theme/GestionThemes.tsx' <<'EOF_THEME_FICHIER'
'use client';
import { useActionState, useEffect, useState, useTransition } from 'react';
import { basculerTheme, enregistrerTheme, supprimerTheme, type EtatThemeForm } from '@/app/theme-actions';
import {
  COULEUR_VALIDE, MODELES, MOTIFS, dateTheme, etatTheme, variablesTheme,
  type MotifTheme, type ThemeAccueil,
} from '@/lib/theme/types';
import { BlocTheme, Neige, PastilleTheme } from '@/components/theme/ThemeAccueil';

const ETATS = {
  en_ligne: { libelle: 'En ligne', classe: 'on' },
  programme: { libelle: 'Programmé', classe: 'new' },
  passe: { libelle: 'Passé', classe: 'off' },
  desactive: { libelle: 'Désactivé', classe: 'off' },
} as const;

const vide = (annee: number): ThemeAccueil => ({
  id: '', nom: '', couleur: '#F591BC', motif: 'aucun', etiquette: '', bandeau: '',
  titre: '', texte: '', bouton: 'En savoir plus', lien: '',
  debut: `${annee}-01-01`, fin: `${annee}-01-31`, actif: true,
});

/** Liste des thèmes programmés, formulaire d'ajout ou de modification, et aperçu. */
export default function GestionThemes({ themes, annee }: { themes: ThemeAccueil[]; annee: number }) {
  const [t, setT] = useState<ThemeAccueil>(vide(annee));
  const [modele, setModele] = useState('');
  const [message, setMessage] = useState('');
  const [etat, action, pending] = useActionState<EtatThemeForm, FormData>(enregistrerTheme, null);
  const [enCours, start] = useTransition();
  const maj = <K extends keyof ThemeAccueil>(cle: K, valeur: ThemeAccueil[K]) => setT((x) => ({ ...x, [cle]: valeur }));

  // Après un enregistrement réussi : retour à un formulaire vide.
  useEffect(() => {
    if (etat?.ok) { setT(vide(annee)); setModele(''); }
  }, [etat, annee]);

  function choisirModele(cle: string) {
    setModele(cle);
    const m = MODELES[cle];
    if (!m) return;
    const { du, au, ...reste } = m;
    setT((x) => ({ ...x, ...reste, debut: `${annee}-${du}`, fin: `${annee}-${au}` }));
  }

  const couleurOk = COULEUR_VALIDE.test(t.couleur);
  const apercu = couleurOk ? t : { ...t, couleur: '#F591BC' };
  const style = variablesTheme(apercu) as React.CSSProperties;

  return (
    <>
      <div className="panel">
        <h2>Thèmes programmés</h2>
        {message && <div className="msg ko">{message}</div>}
        <table className="tbl cartes compact">
          <thead><tr><th>Thème</th><th>Couleur</th><th>Période</th><th>État</th><th></th></tr></thead>
          <tbody>
            {themes.map((x) => {
              const e = ETATS[etatTheme(x)];
              return (
                <tr key={x.id} style={{ opacity: enCours ? .6 : 1 }}>
                  <td data-l="Thème" className="bloc"><strong>{x.nom}</strong></td>
                  <td data-l="Couleur"><i className="th-pt" style={{ background: x.couleur }} /></td>
                  <td data-l="Période">du {dateTheme(x.debut)} au {dateTheme(x.fin)}</td>
                  <td data-l="État"><span className={`pill ${e.classe}`}>{e.libelle}</span></td>
                  <td className="actions">
                    <button type="button" className="btn btn-y btn-sm" onClick={() => { setT(x); setModele(''); }}>Modifier</button>{' '}
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => start(async () => { const r = await basculerTheme(x.id, !x.actif); setMessage(r?.erreur ?? ''); })}>
                      {x.actif ? 'Désactiver' : 'Activer'}
                    </button>{' '}
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => {
                        if (!window.confirm(`Supprimer le thème « ${x.nom} » ?`)) return;
                        start(async () => { const r = await supprimerTheme(x.id); setMessage(r?.erreur ?? ''); });
                      }}>
                      Suppr.
                    </button>
                  </td>
                </tr>
              );
            })}
            {themes.length === 0 && (
              <tr><td colSpan={5} style={{ color: '#6b6560' }}>Aucun thème. Choisis un modèle ci-dessous pour commencer.</td></tr>
            )}
          </tbody>
        </table>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.9rem' }}>
          Un thème s&apos;affiche du premier au dernier jour inclus, puis se retire tout seul. Si deux thèmes se chevauchent,
          le plus récemment commencé s&apos;affiche.
        </p>
      </div>

      <form action={action} className="panel">
        <h2>{t.id ? `Modifier « ${t.nom} »` : 'Ajouter un thème'}</h2>
        {etat?.ok && <div className="msg ok">{etat.ok}</div>}
        {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
        <input type="hidden" name="id" value={t.id} />

        {!t.id && (
          <div className="field">
            <label htmlFor="th-modele">Partir d&apos;un modèle</label>
            <select id="th-modele" value={modele} onChange={(e) => choisirModele(e.target.value)}>
              <option value="">Thème personnalisé</option>
              {Object.entries(MODELES).map(([cle, m]) => <option key={cle} value={cle}>{m.nom}</option>)}
            </select>
          </div>
        )}

        <div className="row3">
          <div className="field">
            <label htmlFor="th-nom">Nom du thème</label>
            <input id="th-nom" name="nom" value={t.nom} maxLength={40} required onChange={(e) => maj('nom', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-debut">Du</label>
            <input id="th-debut" name="debut" type="date" value={t.debut} required onChange={(e) => maj('debut', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-fin">Au (inclus)</label>
            <input id="th-fin" name="fin" type="date" value={t.fin} required onChange={(e) => maj('fin', e.target.value)} />
          </div>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="th-couleur">Couleur du haut de page</label>
            <div style={{ display: 'flex', gap: '.5rem' }}>
              <input type="color" aria-label="Choisir la couleur" value={couleurOk ? t.couleur : '#F591BC'}
                onChange={(e) => maj('couleur', e.target.value.toUpperCase())}
                style={{ width: 56, padding: 2, flex: 'none' }} />
              <input id="th-couleur" name="couleur" value={t.couleur} maxLength={7} required
                onChange={(e) => maj('couleur', e.target.value)} />
            </div>
          </div>
          <div className="field">
            <label htmlFor="th-motif">Motif</label>
            <select id="th-motif" name="motif" value={t.motif} onChange={(e) => maj('motif', e.target.value as MotifTheme)}>
              {Object.entries(MOTIFS).map(([cle, libelle]) => <option key={cle} value={cle}>{libelle}</option>)}
            </select>
          </div>
          <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center', marginTop: '1.4rem' }}>
            <input type="checkbox" name="actif" checked={t.actif} onChange={(e) => maj('actif', e.target.checked)} style={{ width: 'auto' }} />
            Thème activé
          </label>
        </div>

        <div className="row2">
          <div className="field">
            <label htmlFor="th-etiquette">Étiquette au-dessus du titre</label>
            <input id="th-etiquette" name="etiquette" value={t.etiquette} maxLength={60}
              placeholder="Octobre Rose · Limetz-Villez" onChange={(e) => maj('etiquette', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-bandeau">Message du bandeau défilant</label>
            <input id="th-bandeau" name="bandeau" value={t.bandeau} maxLength={80} onChange={(e) => maj('bandeau', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label htmlFor="th-titre">Titre du bloc de message (facultatif)</label>
          <input id="th-titre" name="titre" value={t.titre} maxLength={90} onChange={(e) => maj('titre', e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="th-texte">Texte du bloc de message (facultatif)</label>
          <textarea id="th-texte" name="texte" rows={3} value={t.texte} maxLength={400} onChange={(e) => maj('texte', e.target.value)} />
        </div>
        <div className="row2">
          <div className="field">
            <label htmlFor="th-bouton">Texte du bouton</label>
            <input id="th-bouton" name="bouton" value={t.bouton} maxLength={30} onChange={(e) => maj('bouton', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-lien">Lien du bouton (vide = pas de bouton)</label>
            <input id="th-lien" name="lien" value={t.lien} maxLength={300} placeholder="https://… ou /evenements/…"
              onChange={(e) => maj('lien', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label>Aperçu</label>
          <div className="th-apercu" style={style}>
            <div className="th-apercu-hero">
              <Neige theme={apercu} />
              <PastilleTheme theme={{ ...apercu, nom: apercu.nom || 'Nom du thème' }} />
              <div><span className="kicker mono">{apercu.etiquette || 'Saison · Limetz-Villez'}</span></div>
              <h3>Toute <span className="a1">l&apos;année</span><br /><span className="a2">on fait la fête</span></h3>
            </div>
            <div className="th-bandeau">
              <div className="marquee"><div><span>{apercu.bandeau || 'Message du bandeau'}</span><span>Prochains événements</span></div></div>
            </div>
            <BlocTheme theme={apercu} />
          </div>
        </div>

        <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
          <button className="btn btn-k btn-sm" disabled={pending}>
            {pending ? 'Enregistrement…' : t.id ? 'Enregistrer les modifications' : 'Ajouter le thème'}
          </button>
          {t.id && (
            <button type="button" className="btn btn-w btn-sm" onClick={() => { setT(vide(annee)); setModele(''); }}>
              Annuler la modification
            </button>
          )}
        </div>
      </form>
    </>
  );
}
EOF_THEME_FICHIER
echo "  ✓ src/components/theme/GestionThemes.tsx"
mkdir -p 'src/app/admin/(protected)/theme'
cat > 'src/app/admin/(protected)/theme/page.tsx' <<'EOF_THEME_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { getThemes } from '@/lib/theme/db';
import { themeDuJour } from '@/lib/theme/types';
import GestionThemes from '@/components/theme/GestionThemes';

export const dynamic = 'force-dynamic';

export default async function AdminTheme() {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return <div className="panel"><h2>Accès réservé aux admins</h2></div>;

  const themes = await getThemes();
  const enLigne = themeDuJour(themes);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Thème de l&apos;accueil</h1>
          <p>Habille la page d&apos;accueil le temps d&apos;un mois ou d&apos;une fête, puis revient à la normale tout seul.</p>
        </div>
      </div>
      <div className={`msg ${enLigne ? 'ok' : ''}`} style={enLigne ? undefined : { background: '#fff' }}>
        {enLigne
          ? `En ligne en ce moment : ${enLigne.nom}.`
          : 'Aucun thème en ligne : la page d\u2019accueil a son apparence habituelle.'}
      </div>
      <GestionThemes themes={themes} annee={new Date().getFullYear()} />
    </>
  );
}
EOF_THEME_FICHIER
echo "  ✓ src/app/admin/(protected)/theme/page.tsx"
mkdir -p 'src/app'
cat > 'src/app/page.tsx' <<'EOF_THEME_FICHIER'
import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import MenuButton from '@/components/MenuButton';
import RetourHaut from '@/components/RetourHaut';
import Marquee from '@/components/Marquee';
import Footer from '@/components/Footer';
import RoueRentree from '@/components/roue/RoueRentree';
import BandeauPartenaires from '@/components/BandeauPartenaires';
import { configRoue, getWheelConfig, roueVisible } from '@/lib/roue/db';
import { getThemes } from '@/lib/theme/db';
import { themeDuJour, variablesTheme } from '@/lib/theme/types';
import { BlocTheme, Neige, PastilleTheme } from '@/components/theme/ThemeAccueil';
import { dateCourte, dateLongue, horaires, periode, texteSur } from '@/lib/format';
import type { Partenaire, SiteSettings, Stat, Evenement } from '@/lib/types';

export const revalidate = 60;

export default async function Home() {
  const supabase = await createClient();

  const [{ data: settings }, { data: stats }, { data: evenements }, wheelConfig, { data: partenaires }, { data: tdn }, { data: pn }, themes] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(),
    supabase.from('stats').select('*').order('position'),
    supabase.from('evenements').select('*').eq('publie', true).order('position'),
    getWheelConfig(),
    supabase.from('partenaires').select('*').eq('actif', true).order('position'),
    supabase.from('tdn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
    supabase.from('pn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
    getThemes(),
  ]);
  // Module événementiel : rendu côté serveur uniquement si actif et dans la période.
  const showWheel = roueVisible(wheelConfig);

  const s = settings as SiteSettings;
  const evts = (evenements ?? []) as Evenement[];

  // Thème du moment (Octobre Rose, Noël...) : actif et dans sa période, sinon rien ne change.
  const theme = themeDuJour(themes);
  const styleTheme = theme ? (variablesTheme(theme) as React.CSSProperties) : undefined;
  const annonces = evts.map((e) => `${dateCourte(e.date_debut)} · ${e.titre}`);

  return (
    <>
      <MenuButton tresors={tdn?.module_actif === true} pereNoel={pn?.module_actif === true} />
      <RetourHaut />

      <header className={`hero${theme ? ' th' : ''}`} style={styleTheme ?? { ['--evt' as string]: s.hero_couleur }}>
        {theme && <Neige theme={theme} />}
        <div className="hero-inner">
          <div className="logo-badge">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              className="hero-logo"
              src={s.logo_url || '/logo-cdf.png'}
              alt="Comité des Fêtes de Limetz-Villez"
            />
          </div>
          {theme && <PastilleTheme theme={theme} />}
          <div style={{ marginBottom: '2.4rem' }}>
            <span className="kicker mono">{theme?.etiquette || s.hero_kicker}</span>
          </div>
          <h1>
            {s.hero_titre_1} <span className="jaune">{s.hero_titre_accent}</span>
            <br />
            <span className="cyan">{s.hero_titre_2}</span>
          </h1>
          <p className="hero-tag">{s.hero_texte}</p>
          <div className="hero-cta">
            <a className="btn btn-y" href="#evenements">Voir le programme</a>
            <a className="btn btn-w" href="#benevoles">Devenir bénévole</a>
          </div>
        </div>

        <a className="scroll-hint" href="#evenements">
          <span>Faire défiler</span>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3"
               strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M6 9l6 6 6-6" />
          </svg>
        </a>
      </header>

      {theme ? (
        <>
          <div className="th-bandeau" style={styleTheme}>
            <Marquee items={theme.bandeau ? [theme.bandeau, ...annonces] : annonces} />
          </div>
          <BlocTheme theme={theme} style={styleTheme} />
        </>
      ) : (
        <Marquee items={annonces} />
      )}

      {showWheel && <RoueRentree config={configRoue(wheelConfig)} />}

      <section id="evenements">
        <div className="wrap">
          <div className="head">
            <h2>Le programme</h2>
            <p>Nos rendez-vous de l&apos;année. Cliquez pour les horaires, le lieu et les inscriptions.</p>
          </div>
          <div className="grid">
            {evts.map((e, i) => {
              const fg = texteSur(e.couleur);
              return (
                <Link
                  key={e.id}
                  href={`/evenements/${e.slug}`}
                  className={`poster${fg === '#FFF8EC' ? ' dark' : ''}`}
                  style={{ background: e.couleur, color: fg }}
                >
                  <span className="num">{String(i + 1).padStart(2, '0')}</span>
                  <div>
                    <div className="when">
                      {periode(e.date_debut, e.date_fin)}{horaires(e.heure_debut, e.heure_fin) && ` · ${horaires(e.heure_debut, e.heure_fin)}`}
                    </div>
                    <h3>{e.titre}</h3>
                    <p>{e.chapo}</p>
                  </div>
                  <span className="price">{e.tarif}</span>
                </Link>
              );
            })}
          </div>
        </div>
        <BandeauPartenaires partenaires={(partenaires ?? []) as Partenaire[]} />
      </section>

      <section className="about" id="association">
        <div className="wrap">
          <div className="head"><h2>{s.asso_titre}</h2></div>
          <div className="about-grid">
            <div>
              {s.asso_texte.split('\n\n').map((p, i) => <p key={i}>{p}</p>)}
            </div>
            <div className="stats">
              {(stats as Stat[] ?? []).map((st) => (
                <div className="stat" key={st.id}>
                  <b>{st.valeur}</b>
                  <span>{st.libelle}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="join" id="benevoles">
        <div className="mono" style={{ marginBottom: '1rem' }}>On a besoin de bras</div>
        <h2>{s.benevoles_titre}</h2>
        <p>{s.benevoles_texte}</p>
        <a className="btn btn-y" href={`mailto:${s.email_contact}`}>Nous contacter</a>
      </section>

      <Footer settings={s} evenements={evts} />
    </>
  );
}
EOF_THEME_FICHIER
echo "  ✓ src/app/page.tsx"
mkdir -p 'src/components'
cat > 'src/components/NavAdmin.tsx' <<'EOF_THEME_FICHIER'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LIENS_ADMIN = [
  { href: '/admin', label: 'Tableau de bord' },
  { href: '/admin/evenements', label: 'Événements' },
  { href: '/admin/reservations', label: 'Réservations' },
  { href: '/admin/tresorerie', label: 'Trésorerie' },
  { href: '/admin/compta', label: 'Comptabilité' },
  { href: '/admin/demandes', label: 'Demandes reçues' },
  { href: '/admin/tresors', label: 'Trésors de Noël' },
  { href: '/admin/pere-noel', label: '🎅 Père Noël vidéo' },
  { href: '/admin/roue', label: '🎡 Roue de la Rentrée' },
  { href: '/admin/partenaires', label: 'Partenaires' },
  { href: '/admin/association', label: 'Association' },
  { href: '/admin/theme', label: 'Thème de l\u2019accueil' },
  { href: '/admin/parametres', label: 'Réglages du site' },
  { href: '/admin/maintenance', label: 'Maintenance' },
];

const LIENS_TRESORIER = [
  { href: '/admin/tresorerie', label: 'Trésorerie (lecture seule)' },
  { href: '/admin/compta', label: 'Comptabilité' },
];

export default function NavAdmin({ role = 'admin' }: { role?: 'admin' | 'tresorier' }) {
  const path = usePathname();
  const [ouvert, setOuvert] = useState(false);
  useEffect(() => { setOuvert(false); }, [path]);
  const LIENS = role === 'tresorier' ? LIENS_TRESORIER : LIENS_ADMIN;
  const estActif = (href: string) => (href === '/admin' ? path === '/admin' : path.startsWith(href));
  const courant = LIENS.find((l) => estActif(l.href))?.label ?? 'Menu';

  return (
    <nav className={`adm-nav${ouvert ? ' ouvert' : ''}`}>
      <button type="button" className="adm-nav-btn" aria-expanded={ouvert} onClick={() => setOuvert((v) => !v)}>
        <span>{courant}</span>
        <span aria-hidden="true">{ouvert ? '✕' : '☰'}</span>
      </button>
      <div className="adm-nav-liens">
        {LIENS.map((l) => (
          <Link key={l.href} href={l.href} className={estActif(l.href) ? 'on' : ''}>
            {l.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}
EOF_THEME_FICHIER
echo "  ✓ src/components/NavAdmin.tsx"

echo
echo "Terminé : 9 fichiers écrits. Aucune mise à jour de la base n'est nécessaire."
echo "Ensuite : git add -A && git commit -m 'Thème de la page d accueil' && git push && vercel --prod"
echo "Puis : Admin, Thème de l'accueil, choisir le modèle Octobre Rose et l'ajouter."
