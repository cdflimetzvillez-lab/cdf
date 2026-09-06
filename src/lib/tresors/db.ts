import 'server-only';
import { cookies } from 'next/headers';
import { createAdminClient } from '@/lib/supabase/admin';
import type { Cle, Compte, Mission, MissionPublique, Participant, Progression, Reglages, Lot } from './types';

export const COOKIE_TOKEN = 'tdn_token';
export const COOKIE_ACTIF = 'tdn_actif';

export async function lireReglages(): Promise<Reglages> {
  const db = createAdminClient();
  const { data } = await db.from('tdn_reglages').select('*').eq('id', 1).single();
  return data as Reglages;
}

export async function lireMissions(): Promise<Mission[]> {
  const db = createAdminClient();
  const { data } = await db.from('tdn_missions').select('*').eq('publie', true).order('numero');
  return (data ?? []) as Mission[];
}

export function publique(m: Mission): MissionPublique {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const { reponses, bonne_reponse, ...reste } = m;
  return reste;
}

export async function lireLots(): Promise<Lot[]> {
  const db = createAdminClient();
  const { data } = await db.from('tdn_lots').select('*, tdn_partenaires(nom)').order('position');
  return (data ?? []) as Lot[];
}

/** Compte courant d'après le cookie, ou null. */
export async function compteCourant(): Promise<Compte | null> {
  const jar = await cookies();
  const token = jar.get(COOKIE_TOKEN)?.value;
  if (!token) return null;
  const db = createAdminClient();
  const { data } = await db.from('tdn_comptes').select('*').eq('token', token).maybeSingle();
  return (data as Compte) ?? null;
}

export async function participantsDuCompte(compteId: string): Promise<Participant[]> {
  const db = createAdminClient();
  const { data } = await db.from('tdn_participants').select('*').eq('compte_id', compteId).order('created_at');
  return (data ?? []) as Participant[];
}

/** Progressions de tous les participants d'un compte. */
export async function progressionsDuCompte(compteId: string): Promise<Progression[]> {
  const db = createAdminClient();
  const participants = await participantsDuCompte(compteId);
  if (participants.length === 0) return [];
  const ids = participants.map((p) => p.id);
  const [{ data: prog }, { data: cles }] = await Promise.all([
    db.from('tdn_progressions').select('participant_id, mission_id').in('participant_id', ids),
    db.from('tdn_cles').select('*').in('participant_id', ids),
  ]);
  return participants.map((p) => ({
    participant: p,
    missionsValidees: (prog ?? []).filter((x) => x.participant_id === p.id).map((x) => x.mission_id),
    cle: ((cles ?? []) as Cle[]).find((c) => c.participant_id === p.id) ?? null,
  }));
}

/** Participant actif : cookie, sinon le premier payé, sinon le premier. */
export async function participantActifId(progressions: Progression[]): Promise<string | null> {
  const jar = await cookies();
  const voulu = jar.get(COOKIE_ACTIF)?.value;
  if (voulu && progressions.some((p) => p.participant.id === voulu)) return voulu;
  return (progressions.find((p) => p.participant.paye) ?? progressions[0])?.participant.id ?? null;
}

/** Tout ce qu'il faut pour les pages du jeu : compte + progressions + actif. Null si pas connecté. */
export async function contexteJoueur() {
  const compte = await compteCourant();
  if (!compte) return null;
  const progressions = await progressionsDuCompte(compte.id);
  const actifId = await participantActifId(progressions);
  const actif = progressions.find((p) => p.participant.id === actifId) ?? null;
  return { compte, progressions, actif };
}
