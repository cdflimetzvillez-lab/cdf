import 'server-only';
import { createAdminClient } from '@/lib/supabase/admin';
import type { CommandePn, ReglagesPn, StatsPn } from './types';

export async function lireReglagesPn(): Promise<ReglagesPn> {
  const db = createAdminClient();
  const { data } = await db.from('pn_reglages').select('*').eq('id', 1).single();
  return data as ReglagesPn;
}

export async function lireStatsPn(): Promise<StatsPn> {
  const db = createAdminClient();
  const { data } = await db.from('pn_stats').select('*').single();
  return (data ?? { commandes: 0, ca_centimes: 0, a_generer: 0, a_relire: 0, en_cours: 0, livrees: 0, en_erreur: 0, secondes_video: 0 }) as StatsPn;
}

export async function commandeParId(id: string): Promise<CommandePn | null> {
  const db = createAdminClient();
  const { data } = await db.from('pn_commandes').select('*').eq('id', id).maybeSingle();
  return (data as CommandePn) ?? null;
}

export async function commandeParToken(token: string): Promise<CommandePn | null> {
  if (!token || token.length < 16) return null;
  const db = createAdminClient();
  const { data } = await db.from('pn_commandes').select('*').eq('token', token).maybeSingle();
  return (data as CommandePn) ?? null;
}

export async function commandeParReference(reference: string): Promise<CommandePn | null> {
  const db = createAdminClient();
  const { data } = await db.from('pn_commandes').select('*').eq('reference', reference).maybeSingle();
  return (data as CommandePn) ?? null;
}

export async function listerCommandes(): Promise<CommandePn[]> {
  const db = createAdminClient();
  const { data } = await db.from('pn_commandes').select('*').order('created_at', { ascending: false }).limit(500);
  return (data ?? []) as CommandePn[];
}

export async function majCommande(id: string, patch: Partial<CommandePn>) {
  const db = createAdminClient();
  const { error } = await db.from('pn_commandes').update(patch).eq('id', id);
  if (error) throw new Error(error.message);
}

/** Envoie un fichier dans le bucket public « medias » (dossier pere-noel/) et renvoie son URL publique. */
export async function deposerMedia(chemin: string, contenu: ArrayBuffer | Uint8Array, contentType: string): Promise<string> {
  const db = createAdminClient();
  const nom = `pere-noel/${chemin}`;
  const { error } = await db.storage.from('medias').upload(nom, contenu, { contentType, upsert: true, cacheControl: '31536000' });
  if (error) throw new Error(`Stockage : ${error.message}`);
  return db.storage.from('medias').getPublicUrl(nom).data.publicUrl;
}

export function referencePn() {
  const bloc = () => Math.random().toString(36).slice(2, 8).toUpperCase();
  return `PN-${bloc()}-${bloc().slice(0, 4)}`;
}
