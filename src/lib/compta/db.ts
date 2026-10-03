import type { createClient } from '@/lib/supabase/server';
import { aujourdhui } from '@/lib/compta/format';
import type { Compte, EvenementCompta, Exercice, Journal } from '@/lib/compta/types';

type Db = Awaited<ReturnType<typeof createClient>>;
type Reponse = PromiseLike<{ data: any[] | null; error: { message: string } | null }>;

/**
 * Lit toutes les lignes d'une requête par paquets de 1000
 * (limite par défaut de l'API Supabase).
 */
export async function lireTout<T = any>(requete: (de: number, a: number) => Reponse): Promise<T[]> {
  const PAS = 1000;
  const tout: T[] = [];
  for (let de = 0; ; de += PAS) {
    const { data, error } = await requete(de, de + PAS - 1);
    if (error) throw new Error(error.message);
    tout.push(...((data ?? []) as T[]));
    if (!data || data.length < PAS) break;
  }
  return tout;
}

/** Exercice demandé, sinon celui qui contient la date du jour, sinon le plus récent. */
export async function contexte(supabase: Db, exId?: string) {
  const { data } = await supabase.from('compta_exercices').select('*').order('date_debut');
  const exercices = (data ?? []) as Exercice[];
  const jour = aujourdhui();
  const exercice =
    exercices.find((e) => e.id === exId) ??
    exercices.find((e) => e.date_debut <= jour && jour <= e.date_fin) ??
    exercices[exercices.length - 1] ??
    null;
  return { exercices, exercice };
}

/** Plan comptable, journaux et codes événement. */
export async function referentiel(supabase: Db) {
  const [{ data: comptes }, { data: journaux }, { data: evenements }] = await Promise.all([
    supabase.from('compta_comptes').select('*').order('numero'),
    supabase.from('compta_journaux').select('*').order('code'),
    supabase.from('compta_evenements').select('id, code, libelle, date_evenement, statut').order('code'),
  ]);
  return {
    comptes: (comptes ?? []) as Compte[],
    journaux: (journaux ?? []) as Journal[],
    evenements: (evenements ?? []) as EvenementCompta[],
  };
}

/** Ajoute ?ex= aux liens quand un exercice autre que l'exercice courant est affiché. */
export function suffixeEx(ex?: string, premier = true): string {
  return ex ? `${premier ? '?' : '&'}ex=${ex}` : '';
}
