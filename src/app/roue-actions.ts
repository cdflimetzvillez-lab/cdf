'use server';

import { createHash } from 'crypto';
import { cookies, headers } from 'next/headers';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { configRoue, getWheelConfig, roueVisible } from '@/lib/roue/db';
import { NB_SEGMENTS, SEGMENTS_GAGNANTS, type LotRoue } from '@/lib/roue/types';

export type EtatRoue = { ok?: string; erreur?: string } | null;

const COOKIE = 'roue_joueur';
const MAX_PAR_IP = 15; // garde-fou contre les cookies effacés en boucle

function jourParis() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
}

function codeGagnant() {
  const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 5; i++) s += a[Math.floor(Math.random() * a.length)];
  return `RR-${s}`;
}

async function joueurId() {
  const jar = await cookies();
  let id = jar.get(COOKIE)?.value;
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) {
    id = crypto.randomUUID();
    jar.set(COOKIE, id, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', maxAge: 60 * 60 * 24 * 90, path: '/' });
  }
  return id;
}

async function ipHash() {
  const h = await headers();
  const ip = (h.get('x-forwarded-for') ?? '').split(',')[0].trim() || h.get('x-real-ip') || '';
  return ip ? createHash('sha256').update(ip + (process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').slice(0, 8)).digest('hex').slice(0, 32) : null;
}

export type ResultatTour =
  | { statut: 'ok'; participationId: string; gagne: boolean; segment: number; lot?: { nom: string; description: string | null }; code?: string }
  | { statut: 'deja_joue'; message: string }
  | { statut: 'ferme'; message: string }
  | { statut: 'erreur'; message: string };

/** Un tour de roue. Tout est décidé ici : le navigateur ne fait qu'animer. */
export async function jouer(): Promise<ResultatTour> {
  const module = await getWheelConfig();
  if (!roueVisible(module)) return { statut: 'ferme', message: 'La roue n’est pas disponible pour le moment.' };
  const cfg = configRoue(module);
  const db = createAdminClient();
  const id = await joueurId();
  const ip = await ipHash();
  const jour = jourParis();

  const { count: dejaJoueur } = await db.from('roue_participations').select('id', { count: 'exact', head: true }).eq('joueur_id', id).eq('jour', jour);
  if ((dejaJoueur ?? 0) >= cfg.participations_par_jour) {
    return { statut: 'deja_joue', message: cfg.participations_par_jour > 1 ? `Vous avez déjà joué ${cfg.participations_par_jour} fois aujourd’hui. À demain !` : 'Vous avez déjà joué aujourd’hui. Revenez demain !' };
  }
  if (ip) {
    const { count: dejaIp } = await db.from('roue_participations').select('id', { count: 'exact', head: true }).eq('ip_hash', ip).eq('jour', jour);
    if ((dejaIp ?? 0) >= MAX_PAR_IP) return { statut: 'deja_joue', message: 'Trop de participations depuis cette connexion aujourd’hui.' };
  }

  // Tirage : taux de gain, puis lot pondéré parmi ceux qui ont du stock.
  let lot: LotRoue | null = null;
  if (Math.random() * 100 < cfg.taux_gain) {
    const { data: lots } = await db.from('roue_lots').select('*').eq('actif', true).gt('stock', 0);
    const { data: attribs } = await db.from('roue_participations').select('lot_id').not('lot_id', 'is', null);
    const pris: Record<string, number> = {};
    for (const a of attribs ?? []) pris[a.lot_id!] = (pris[a.lot_id!] ?? 0) + 1;
    const dispo = ((lots ?? []) as LotRoue[]).filter((l) => l.stock - (pris[l.id] ?? 0) > 0);
    const total = dispo.reduce((s, l) => s + Math.max(l.poids, 0), 0);
    if (total > 0) {
      let r = Math.random() * total;
      for (const l of dispo) { r -= Math.max(l.poids, 0); if (r <= 0) { lot = l; break; } }
      lot ??= dispo[dispo.length - 1];
    }
  }
  const gagne = !!lot;
  const pool = gagne ? SEGMENTS_GAGNANTS : Array.from({ length: NB_SEGMENTS }, (_, i) => i).filter((i) => !SEGMENTS_GAGNANTS.includes(i));
  const segment = pool[Math.floor(Math.random() * pool.length)];

  let code: string | null = null;
  let inserted: { id: string } | null = null;
  for (let essai = 0; essai < 5 && !inserted; essai++) {
    code = gagne ? codeGagnant() : null;
    const { data, error } = await db.from('roue_participations').insert({ joueur_id: id, ip_hash: ip, jour, gagne, lot_id: lot?.id ?? null, code }).select('id').single();
    if (!error && data) inserted = data;
    else if (error?.code !== '23505') { console.error('[roue] insert', error); return { statut: 'erreur', message: 'Impossible d’enregistrer votre participation.' }; }
  }
  if (!inserted) return { statut: 'erreur', message: 'Réessayez dans un instant.' };

  return gagne
    ? { statut: 'ok', participationId: inserted.id, gagne: true, segment, lot: { nom: lot!.nom, description: lot!.description }, code: code! }
    : { statut: 'ok', participationId: inserted.id, gagne: false, segment };
}

/** Le gagnant laisse ses coordonnées pour récupérer son lot. */
export async function reclamer(_prev: EtatRoue, fd: FormData): Promise<EtatRoue> {
  const participationId = String(fd.get('participation_id') ?? '');
  const prenom = String(fd.get('prenom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone = String(fd.get('telephone') ?? '').trim();
  if (!prenom) return { erreur: 'Indiquez votre prénom.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse e-mail invalide.' };
  const id = await joueurId();
  const db = createAdminClient();
  const { error } = await db.from('roue_participations')
    .update({ prenom, email, telephone: telephone || null, reclame_le: new Date().toISOString() })
    .eq('id', participationId).eq('joueur_id', id).eq('gagne', true);
  if (error) return { erreur: 'Enregistrement impossible.' };
  return { ok: 'C’est noté ! Gardez votre code précieusement.' };
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) throw new Error('Accès refusé.');
  return supabase;
}
const rafraichir = () => { revalidatePath('/'); revalidatePath('/admin/roue', 'layout'); };

export async function basculerRoue(active: boolean): Promise<EtatRoue> {
  const sb = await admin();
  const { error } = await sb.from('homepage_modules').update({ is_active: active }).eq('module_key', 'roue_rentree');
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: active ? '✓ La Roue de la Rentrée est activée.' : '✓ La Roue de la Rentrée a été désactivée.' };
}

/** Convertit un datetime-local (heure de Paris) en ISO. */
function isoParis(v: string) {
  if (!v) return null;
  // datetime-local sans fuseau : on le considère en heure de Paris.
  const d = new Date(v);
  const paris = new Date(d.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  const decalage = d.getTime() - paris.getTime();
  return new Date(d.getTime() + decalage).toISOString();
}

export async function majModuleRoue(_prev: EtatRoue, fd: FormData): Promise<EtatRoue> {
  const sb = await admin();
  const config = {
    titre: String(fd.get('titre') ?? '').trim(),
    accroche: String(fd.get('accroche') ?? '').trim(),
    periode_texte: String(fd.get('periode_texte') ?? '').trim(),
    participations_par_jour: Math.max(1, Number(fd.get('participations_par_jour') ?? 1)),
    taux_gain: Math.min(100, Math.max(0, Number(fd.get('taux_gain') ?? 12))),
    message_gagne: String(fd.get('message_gagne') ?? '').trim(),
    message_perdu: String(fd.get('message_perdu') ?? '').trim(),
  };
  const { error } = await sb.from('homepage_modules').update({
    is_active: fd.get('is_active') === 'on',
    start_date: isoParis(String(fd.get('start_date') ?? '')),
    end_date: isoParis(String(fd.get('end_date') ?? '')),
    config,
  }).eq('module_key', 'roue_rentree');
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Paramètres enregistrés.' };
}

export async function enregistrerLotRoue(_prev: EtatRoue, fd: FormData): Promise<EtatRoue> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const data = {
    nom: String(fd.get('nom') ?? '').trim(),
    description: String(fd.get('description') ?? '').trim() || null,
    stock: Math.max(0, Number(fd.get('stock') ?? 1)),
    poids: Math.max(0, Number(fd.get('poids') ?? 1)),
    actif: fd.get('actif') === 'on',
    position: Number(fd.get('position') ?? 0),
  };
  if (!data.nom) return { erreur: 'Nom du lot obligatoire.' };
  const { error } = id ? await sb.from('roue_lots').update(data).eq('id', id) : await sb.from('roue_lots').insert(data);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Lot enregistré.' };
}

export async function supprimerLotRoue(id: string) {
  const sb = await admin();
  await sb.from('roue_lots').delete().eq('id', id);
  rafraichir();
}

export async function marquerRetire(id: string, retire: boolean) {
  const sb = await admin();
  await sb.from('roue_participations').update({ retire_le: retire ? new Date().toISOString() : null }).eq('id', id);
  rafraichir();
}
