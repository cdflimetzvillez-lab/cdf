import 'server-only';
import { createAdminClient } from '@/lib/supabase/admin';
import { CONFIG_DEFAUT, type ConfigRoue, type ModuleAccueil } from './types';

export async function getWheelConfig(): Promise<ModuleAccueil | null> {
  const db = createAdminClient();
  const { data } = await db.from('homepage_modules').select('*').eq('module_key', 'roue_rentree').maybeSingle();
  return (data as ModuleAccueil) ?? null;
}

export function configRoue(m: ModuleAccueil | null): ConfigRoue {
  return { ...CONFIG_DEFAUT, ...(m?.config ?? {}) };
}

/** Visible publiquement : actif ET dans la fenêtre de dates (bornes facultatives). */
export function roueVisible(m: ModuleAccueil | null, maintenant = new Date()): boolean {
  if (!m || !m.is_active) return false;
  if (m.start_date && maintenant < new Date(m.start_date)) return false;
  if (m.end_date && maintenant > new Date(m.end_date)) return false;
  return true;
}
