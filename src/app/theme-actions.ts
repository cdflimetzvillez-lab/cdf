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
