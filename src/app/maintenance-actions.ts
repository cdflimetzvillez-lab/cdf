'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';

export type EtatMaintenance = { ok?: string; erreur?: string } | null;

/** Active ou coupe le mode maintenance. */
export async function basculerMaintenance(actif: boolean) {
  const { supabase, isAdmin } = await requireAdmin('maintenance');
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const { error } = await supabase
    .from('site_settings')
    .update({
      maintenance_active: actif,
      maintenance_depuis: actif ? new Date().toISOString() : null,
    })
    .eq('id', 1);

  if (error) return { erreur: error.message };

  revalidatePath('/', 'layout');
  return { ok: actif ? 'Site coupé.' : 'Site remis en ligne.' };
}

/** Enregistre les textes affichés pendant la coupure. */
export async function majTextesMaintenance(
  _prev: EtatMaintenance, fd: FormData
): Promise<EtatMaintenance> {
  const { supabase, isAdmin } = await requireAdmin('maintenance');
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const titre = String(fd.get('maintenance_titre') ?? '').trim();
  if (!titre) return { erreur: 'Le titre ne peut pas être vide.' };

  const { error } = await supabase
    .from('site_settings')
    .update({
      maintenance_titre: titre,
      maintenance_message: String(fd.get('maintenance_message') ?? '').trim(),
      maintenance_retour: String(fd.get('maintenance_retour') ?? '').trim() || null,
    })
    .eq('id', 1);

  if (error) return { erreur: error.message };

  revalidatePath('/', 'layout');
  revalidatePath('/admin/maintenance');
  return { ok: 'Textes enregistrés.' };
}
