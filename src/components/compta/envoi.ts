'use client';
import { createClient } from '@/lib/supabase/client';

const TAILLE_MAX = 10 * 1024 * 1024; // 10 Mo
const TYPES = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/heic'];
export const ACCEPT_JUSTIFICATIF = '.pdf,image/jpeg,image/png,image/webp,image/heic';

/** Envoie un justificatif dans le stockage privé et renvoie son chemin. */
export async function envoyerJustificatif(fichier: File, annee: string): Promise<string> {
  if (fichier.type && !TYPES.includes(fichier.type)) {
    throw new Error('Formats acceptés : PDF, JPG, PNG, WebP ou HEIC.');
  }
  if (fichier.size > TAILLE_MAX) {
    throw new Error(`Fichier trop lourd (${(fichier.size / 1024 / 1024).toFixed(1)} Mo). Maximum 10 Mo.`);
  }
  const ext = fichier.name.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g, '') || 'pdf';
  const chemin = `${annee}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const { error } = await createClient().storage.from('compta-justificatifs').upload(chemin, fichier, { upsert: false });
  if (error) {
    throw new Error(
      error.message.includes('row-level security')
        ? 'Envoi refusé : droits insuffisants sur le stockage des justificatifs.'
        : "L'envoi du justificatif a échoué. Réessaie."
    );
  }
  return chemin;
}
