'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';

/** Fixe le nombre de personnes arrivées sur une réservation. */
export async function majArrivees(id: string, arrivees: number) {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };

  const { data: resa } = await supabase
    .from('reservations')
    .select('places')
    .eq('id', id)
    .maybeSingle();

  if (!resa) return { erreur: 'Réservation introuvable.' };

  const valeur = Math.max(0, Math.min(arrivees, resa.places));

  const { error } = await supabase
    .from('reservations')
    .update({
      places_arrivees: valeur,
      scanne_le: valeur > 0 ? new Date().toISOString() : null,
    })
    .eq('id', id);

  if (error) return { erreur: error.message };

  revalidatePath('/admin/pointage/[id]', 'page');
  revalidatePath('/admin/reservations');
  return { ok: true, arrivees: valeur };
}
