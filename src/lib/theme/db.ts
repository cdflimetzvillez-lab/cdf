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
