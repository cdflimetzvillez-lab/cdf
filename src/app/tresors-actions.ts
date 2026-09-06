'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout } from '@/lib/sumup';
import { COOKIE_ACTIF, COOKIE_TOKEN, compteCourant, jeuOuvert, lireMissions, lireReglages, placesPrises } from '@/lib/tresors/db';
import type { Categorie, Cle, Lot, Mission, Bloc } from '@/lib/tresors/types';
import { numeroCle } from '@/lib/tresors/types';

export type Etat = { ok?: string; erreur?: string } | null;

const UN_AN = 60 * 60 * 24 * 365;
const normaliser = (s: string) => s.trim().toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ');
const emailValide = (e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);

async function poserCookieToken(token: string) {
  const jar = await cookies();
  jar.set(COOKIE_TOKEN, token, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', maxAge: UN_AN, path: '/' });
}

function genererCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 4; i++) s += alphabet[Math.floor(Math.random() * alphabet.length)];
  return `NOEL-${s}`;
}

function referenceCommande() {
  const bloc = () => Math.random().toString(36).slice(2, 8).toUpperCase();
  return `TDN-${bloc()}-${bloc().slice(0, 4)}`;
}

/* =========================================================
   INSCRIPTION + PAIEMENT SUMUP
   ========================================================= */
export async function inscrire(_prev: Etat, fd: FormData): Promise<Etat> {
  const reglages = await lireReglages();
  if (!reglages.inscriptions_ouvertes) return { erreur: 'Les inscriptions sont fermées.' };

  const prenom = String(fd.get('prenom') ?? '').trim();
  const nom = String(fd.get('nom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone = String(fd.get('telephone') ?? '').trim();
  const prenoms = fd.getAll('participant_prenom').map((v) => String(v).trim());
  const categories = fd.getAll('participant_categorie').map((v) => String(v) as Categorie);

  if (!prenom || !nom) return { erreur: 'Prénom et nom du responsable obligatoires.' };
  if (!emailValide(email)) return { erreur: 'Adresse e-mail invalide.' };
  const lignes = prenoms.map((p, i) => ({ prenom: p, categorie: categories[i] === 'adulte' ? 'adulte' : 'enfant' as Categorie })).filter((l) => l.prenom);
  if (lignes.length === 0) return { erreur: 'Ajoutez au moins un participant.' };
  const restantes = reglages.places_max - (await placesPrises());
  if (restantes <= 0) return { erreur: 'Complet : toutes les places ont été réservées.' };
  if (lignes.length > restantes) return { erreur: `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}. Réduisez le nombre de participants.` };

  const db = createAdminClient();

  // Compte : réutilise celui du cookie si présent, sinon crée.
  const existant = await compteCourant();
  let compteId: string;
  if (existant) {
    compteId = existant.id;
  } else {
    const { data, error } = await db.from('tdn_comptes').insert({ prenom, nom, email, telephone: telephone || null }).select('*').single();
    if (error || !data) { console.error('[inscrire] compte', error); return { erreur: 'Impossible de créer le compte.' }; }
    compteId = data.id;
    await poserCookieToken(data.token);
  }
  const { data: participants, error: errP } = await db
    .from('tdn_participants')
    .insert(lignes.map((l) => ({ compte_id: compteId, prenom: l.prenom, categorie: l.categorie, paye: false })))
    .select('id, categorie');
  if (errP || !participants) { console.error('[inscrire] participants', errP); return { erreur: 'Impossible d’enregistrer les participants.' }; }

  const montant = participants.reduce((s, p) => s + (p.categorie === 'adulte' ? reglages.tarif_adulte_centimes : reglages.tarif_enfant_centimes), 0);
  const reference = referenceCommande();
  const ids = participants.map((p) => p.id);

  const { data: cmd, error: errC } = await db.from('tdn_commandes')
    .insert({ compte_id: compteId, reference, montant_centimes: montant, participant_ids: ids, statut: 'en_attente' })
    .select('id').single();
  if (errC || !cmd) { console.error('[inscrire] commande', errC); return { erreur: 'Impossible de créer la commande.' }; }

  // Gratuit (tarifs à 0) : validation directe.
  if (montant === 0) {
    await db.from('tdn_commandes').update({ statut: 'payee', paye_le: new Date().toISOString() }).eq('id', cmd.id);
    await db.from('tdn_participants').update({ paye: true }).in('id', ids);
    redirect('/tresors-de-noel/inscription/retour?ref=' + reference);
  }

  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  let url: string | undefined;
  try {
    const checkout = await creerCheckout({
      reference,
      montantCentimes: montant,
      description: `${reference} · Trésors de Noël · ${lignes.length} participant${lignes.length > 1 ? 's' : ''}`,
      emailClient: email,
      urlRetour: `${base}/tresors-de-noel/inscription/retour?ref=${reference}`,
    });
    await db.from('tdn_commandes').update({ checkout_id: checkout.id }).eq('id', cmd.id);
    url = checkout.hosted_checkout_url;
  } catch (e) {
    console.error('[inscrire] SumUp', e);
    await db.from('tdn_commandes').update({ statut: 'echouee' }).eq('id', cmd.id);
    return { erreur: 'Le service de paiement est indisponible. Réessayez plus tard.' };
  }
  if (!url) return { erreur: 'Le paiement n’a pas pu être initialisé.' };
  redirect(url);
}

/** Synchronise une commande avec SumUp (retour de paiement ou webhook). */
export async function synchroniserCommande(reference?: string, checkoutId?: string) {
  const db = createAdminClient();
  const req = db.from('tdn_commandes').select('*');
  const { data: cmd } = await (reference ? req.eq('reference', reference) : req.eq('checkout_id', checkoutId!)).maybeSingle();
  if (!cmd) return null;
  if (cmd.statut === 'payee' || !cmd.checkout_id) return cmd;

  try {
    const checkout = await lireCheckout(cmd.checkout_id);
    const corr: Record<string, string> = { PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente' };
    const statut = corr[checkout.status] ?? 'en_attente';
    if (statut === cmd.statut) return cmd;
    const { data: maj } = await db.from('tdn_commandes').update({
      statut,
      transaction_code: checkout.transaction_code ?? checkout.transactions?.[0]?.transaction_code ?? null,
      paye_le: statut === 'payee' ? new Date().toISOString() : null,
    }).eq('id', cmd.id).select('*').single();
    if (statut === 'payee') await db.from('tdn_participants').update({ paye: true }).in('id', cmd.participant_ids);
    return maj ?? cmd;
  } catch (e) {
    console.error('[synchroniserCommande]', e);
    return cmd;
  }
}

/** Relance un paiement pour les participants non payés du compte courant. */
export async function payerEnAttente(): Promise<Etat> {
  const compte = await compteCourant();
  if (!compte) return { erreur: 'Non connecté.' };
  const reglages = await lireReglages();
  const db = createAdminClient();
  const { data: parts } = await db.from('tdn_participants').select('id, categorie').eq('compte_id', compte.id).eq('paye', false);
  if (!parts || parts.length === 0) return { erreur: 'Rien à payer.' };
  const restantes = reglages.places_max - (await placesPrises());
  if (parts.length > restantes) return { erreur: restantes <= 0 ? 'Complet : toutes les places ont été réservées.' : `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}.` };
  const montant = parts.reduce((s, p) => s + (p.categorie === 'adulte' ? reglages.tarif_adulte_centimes : reglages.tarif_enfant_centimes), 0);
  const reference = referenceCommande();
  const ids = parts.map((p) => p.id);
  const { data: cmd } = await db.from('tdn_commandes').insert({ compte_id: compte.id, reference, montant_centimes: montant, participant_ids: ids }).select('id').single();
  if (!cmd) return { erreur: 'Impossible de créer la commande.' };
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  let url: string | undefined;
  try {
    const checkout = await creerCheckout({ reference, montantCentimes: montant, description: `${reference} · Trésors de Noël`, emailClient: compte.email,
      urlRetour: `${base}/tresors-de-noel/inscription/retour?ref=${reference}` });
    await db.from('tdn_commandes').update({ checkout_id: checkout.id }).eq('id', cmd.id);
    url = checkout.hosted_checkout_url;
  } catch (e) { console.error('[payerEnAttente]', e); return { erreur: 'Paiement indisponible.' }; }
  if (!url) return { erreur: 'Paiement indisponible.' };
  redirect(url);
}

/* =========================================================
   ACCÈS AU COMPTE (jeton par e-mail)
   ========================================================= */
export async function envoyerLienAcces(_prev: Etat, fd: FormData): Promise<Etat> {
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  if (!emailValide(email)) return { erreur: 'Adresse e-mail invalide.' };
  const db = createAdminClient();
  const { data: comptes } = await db.from('tdn_comptes').select('token, prenom').ilike('email', email);
  const generique = { ok: 'Si un compte existe avec cette adresse, un lien d’accès vient d’être envoyé.' };
  if (!comptes || comptes.length === 0 || !process.env.RESEND_API_KEY) return generique;

  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  const from = process.env.RESEND_FROM_EMAIL ?? 'Comité des Fêtes de Limetz-Villez <billetterie@cdf-limetzvillez.fr>';
  const lien = `${base}/api/tresors/acces?token=${comptes[0].token}`;
  try {
    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from, to: [email], subject: 'Votre accès aux Trésors de Noël',
        html: `<p>Bonjour ${comptes[0].prenom},</p><p>Voici votre lien pour retrouver votre aventure et vos clés :</p><p><a href="${lien}">${lien}</a></p><p>Ce lien est personnel, ne le partagez pas.</p><p>Comité des Fêtes de Limetz-Villez</p>`,
        text: `Bonjour ${comptes[0].prenom},\n\nVotre lien d'accès : ${lien}\n\nComité des Fêtes de Limetz-Villez`,
      }),
    });
  } catch (e) { console.error('[envoyerLienAcces]', e); }
  return generique;
}

export async function deconnecter() {
  const jar = await cookies();
  jar.delete(COOKIE_TOKEN);
  jar.delete(COOKIE_ACTIF);
  redirect('/tresors-de-noel');
}

export async function choisirParticipant(id: string) {
  const jar = await cookies();
  jar.set(COOKIE_ACTIF, id, { httpOnly: true, sameSite: 'lax', maxAge: UN_AN, path: '/' });
  revalidatePath('/tresors-de-noel', 'layout');
}

export async function ajouterParticipant(_prev: Etat, fd: FormData): Promise<Etat> {
  const compte = await compteCourant();
  if (!compte) return { erreur: 'Non connecté.' };
  const prenom = String(fd.get('prenom') ?? '').trim();
  const categorie: Categorie = fd.get('categorie') === 'adulte' ? 'adulte' : 'enfant';
  if (!prenom) return { erreur: 'Prénom obligatoire.' };
  const db = createAdminClient();
  await db.from('tdn_participants').insert({ compte_id: compte.id, prenom, categorie, paye: false });
  revalidatePath('/tresors-de-noel', 'layout');
  return { ok: `${prenom} ajouté. Réglez sa participation pour l’activer.` };
}

export async function supprimerParticipant(id: string) {
  const compte = await compteCourant();
  if (!compte) return;
  const db = createAdminClient();
  // On ne supprime que les participants non payés du compte courant.
  await db.from('tdn_participants').delete().eq('id', id).eq('compte_id', compte.id).eq('paye', false);
  revalidatePath('/tresors-de-noel', 'layout');
}

/* =========================================================
   JEU — validation d'une réponse (côté serveur)
   ========================================================= */
export async function validerReponse(missionId: string, reponse: string, participantIds: string[]): Promise<{ ok: boolean; termines: string[]; erreur?: string }> {
  const compte = await compteCourant();
  if (!compte) return { ok: false, termines: [], erreur: 'Non connecté.' };
  const reglages = await lireReglages();
  if (!jeuOuvert(reglages)) return { ok: false, termines: [], erreur: 'Le jeu n’est pas ouvert pour le moment.' };

  const db = createAdminClient();
  const { data: mission } = await db.from('tdn_missions').select('*').eq('id', missionId).single();
  if (!mission) return { ok: false, termines: [], erreur: 'Mission introuvable.' };
  const m = mission as Mission;

  const bon = m.question_type === 'choix'
    ? Number(reponse) === m.bonne_reponse
    : m.reponses.map(normaliser).includes(normaliser(reponse));
  if (!bon) return { ok: false, termines: [] };

  // Participants autorisés : payés et appartenant au compte.
  const { data: parts } = await db.from('tdn_participants').select('id').eq('compte_id', compte.id).eq('paye', true).in('id', participantIds);
  const ids = (parts ?? []).map((p) => p.id);
  if (ids.length === 0) return { ok: true, termines: [], erreur: 'Aucun participant valide sélectionné.' };

  await db.from('tdn_progressions').upsert(ids.map((participant_id) => ({ participant_id, mission_id: missionId })), { onConflict: 'participant_id,mission_id', ignoreDuplicates: true });

  // Clés pour ceux qui viennent de terminer.
  const missions = await lireMissions();
  const total = missions.length;
  const { data: prog } = await db.from('tdn_progressions').select('participant_id, mission_id').in('participant_id', ids);
  const idsMissions = new Set(missions.map((x) => x.id));
  const termines: string[] = [];
  for (const id of ids) {
    const faites = (prog ?? []).filter((p) => p.participant_id === id && idsMissions.has(p.mission_id)).length;
    if (faites >= total) {
      const { data: existante } = await db.from('tdn_cles').select('id').eq('participant_id', id).maybeSingle();
      if (!existante) {
        // Code unique : on retente en cas de collision.
        for (let essai = 0; essai < 5; essai++) {
          const { error } = await db.from('tdn_cles').insert({ participant_id: id, code: genererCode() });
          if (!error) break;
        }
        termines.push(id);
      }
    }
  }
  revalidatePath('/tresors-de-noel', 'layout');
  return { ok: true, termines };
}

/* =========================================================
   RÉVÉLATION (écran du Marché de Noël)
   ========================================================= */
export async function reveler(numero: string, code: string): Promise<{ lot?: Lot; prenom?: string; dejaRevelee?: boolean; erreur?: string }> {
  const n = Number(numero.trim());
  const c = code.trim().toUpperCase();
  if (!n || !c) return { erreur: 'Clé incomplète.' };
  const db = createAdminClient();
  const { data: cle } = await db.from('tdn_cles').select('*, tdn_participants(prenom)').eq('numero', n).eq('code', c).maybeSingle();
  if (!cle) return { erreur: 'Clé inconnue. Vérifiez le numéro et le code secret.' };

  let lotId: string | null = cle.lot_id;
  if (!lotId) {
    // Attribution : un lot non « grand » avec du stock restant, tiré au sort.
    const { data: lots } = await db.from('tdn_lots').select('id, stock').eq('grand', false);
    const { data: attribs } = await db.from('tdn_cles').select('lot_id').not('lot_id', 'is', null);
    const compte: Record<string, number> = {};
    for (const a of attribs ?? []) compte[a.lot_id!] = (compte[a.lot_id!] ?? 0) + 1;
    const dispo: string[] = [];
    for (const l of lots ?? []) for (let i = (compte[l.id] ?? 0); i < l.stock; i++) dispo.push(l.id);
    if (dispo.length === 0) return { erreur: 'Plus aucun lot disponible. Adressez-vous aux bénévoles.' };
    lotId = dispo[Math.floor(Math.random() * dispo.length)];
  }
  const dejaRevelee = !!cle.revelee_le;
  await db.from('tdn_cles').update({ lot_id: lotId, revelee_le: cle.revelee_le ?? new Date().toISOString() }).eq('id', cle.id);
  const { data: lot } = await db.from('tdn_lots').select('*, tdn_partenaires(nom)').eq('id', lotId).single();
  return { lot: lot as Lot, prenom: (cle as { tdn_participants?: { prenom: string } }).tdn_participants?.prenom, dejaRevelee };
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) throw new Error('Accès refusé.');
  return supabase;
}
const chemins = () => { revalidatePath('/admin/tresors', 'layout'); revalidatePath('/tresors-de-noel', 'layout'); };

function isoParisTdn(v: string) {
  if (!v) return null;
  const d = new Date(v);
  const paris = new Date(d.toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
  return new Date(d.getTime() + (d.getTime() - paris.getTime())).toISOString();
}

export async function majReglagesTdn(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const { error } = await sb.from('tdn_reglages').update({
    titre: String(fd.get('titre') ?? '').trim(),
    accroche: String(fd.get('accroche') ?? '').trim(),
    periode_texte: String(fd.get('periode_texte') ?? '').trim(),
    marche_texte: String(fd.get('marche_texte') ?? '').trim(),
    duree_texte: String(fd.get('duree_texte') ?? '').trim(),
    tarif_adulte_centimes: Math.round(Number(fd.get('tarif_adulte') ?? 0) * 100),
    tarif_enfant_centimes: Math.round(Number(fd.get('tarif_enfant') ?? 0) * 100),
    inscriptions_ouvertes: fd.get('inscriptions_ouvertes') === 'on',
    jeu_actif: fd.get('jeu_actif') === 'on',
    places_max: Math.max(0, Number(fd.get('places_max') ?? 300)),
    jeu_debut: isoParisTdn(String(fd.get('jeu_debut') ?? '')),
    jeu_fin: isoParisTdn(String(fd.get('jeu_fin') ?? '')),
    grand_tresor_montant: String(fd.get('grand_tresor_montant') ?? '').trim(),
    grand_tresor_texte: String(fd.get('grand_tresor_texte') ?? '').trim(),
    lieu_revelation: String(fd.get('lieu_revelation') ?? '').trim(),
  }).eq('id', 1);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Réglages enregistrés.' };
}

const lignes = (v: FormDataEntryValue | null) => String(v ?? '').split('\n').map((s) => s.trim()).filter(Boolean);

export async function enregistrerMission(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const question_type = String(fd.get('question_type') ?? 'texte');
  let blocs: Bloc[] = [];
  try { blocs = JSON.parse(String(fd.get('blocs') ?? '[]')); } catch { return { erreur: 'Contenu (blocs) invalide.' }; }
  const options = lignes(fd.get('options'));
  const data = {
    numero: Number(fd.get('numero') ?? 0),
    titre: String(fd.get('titre') ?? '').trim(),
    lieu: String(fd.get('lieu') ?? '').trim() || null,
    accroche: String(fd.get('accroche') ?? '').trim() || null,
    blocs,
    question_type,
    intitule: String(fd.get('intitule') ?? '').trim(),
    reponses: lignes(fd.get('reponses')),
    options,
    bonne_reponse: question_type === 'choix' ? Number(fd.get('bonne_reponse') ?? 0) : null,
    longueur: question_type === 'code' ? Number(fd.get('longueur') ?? 4) || null : null,
    placeholder: String(fd.get('placeholder') ?? '').trim() || null,
    indices: lignes(fd.get('indices')),
    solution_secours: String(fd.get('solution_secours') ?? '').trim() || null,
    publie: fd.get('publie') === 'on',
  };
  if (!data.titre || !data.numero) return { erreur: 'Numéro et titre obligatoires.' };
  if (question_type !== 'choix' && data.reponses.length === 0) return { erreur: 'Indiquez au moins une réponse acceptée.' };
  if (question_type === 'choix' && options.length < 2) return { erreur: 'Au moins deux options pour un choix multiple.' };

  const { error } = id
    ? await sb.from('tdn_missions').update(data).eq('id', id)
    : await sb.from('tdn_missions').insert(data);
  if (error) return { erreur: error.code === '23505' ? 'Ce numéro de mission existe déjà.' : error.message };
  chemins();
  if (!id) redirect('/admin/tresors/missions');
  return { ok: 'Mission enregistrée.' };
}

export async function supprimerMission(id: string) {
  const sb = await admin();
  await sb.from('tdn_missions').delete().eq('id', id);
  chemins();
  redirect('/admin/tresors/missions');
}

export async function enregistrerLot(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const data = {
    nom: String(fd.get('nom') ?? '').trim(),
    valeur: String(fd.get('valeur') ?? '').trim() || null,
    partenaire_id: String(fd.get('partenaire_id') ?? '') || null,
    stock: Number(fd.get('stock') ?? 1),
    grand: fd.get('grand') === 'on',
    position: Number(fd.get('position') ?? 0),
  };
  if (!data.nom) return { erreur: 'Nom du lot obligatoire.' };
  const { error } = id ? await sb.from('tdn_lots').update(data).eq('id', id) : await sb.from('tdn_lots').insert(data);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Lot enregistré.' };
}
export async function supprimerLot(id: string) { const sb = await admin(); await sb.from('tdn_lots').delete().eq('id', id); chemins(); }

export async function enregistrerPartenaire(_prev: Etat, fd: FormData): Promise<Etat> {
  const sb = await admin();
  const id = String(fd.get('id') ?? '');
  const data = { nom: String(fd.get('nom') ?? '').trim(), type: String(fd.get('type') ?? '').trim() || null };
  if (!data.nom) return { erreur: 'Nom obligatoire.' };
  const { error } = id ? await sb.from('tdn_partenaires').update(data).eq('id', id) : await sb.from('tdn_partenaires').insert(data);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Partenaire enregistré.' };
}
export async function supprimerPartenaire(id: string) { const sb = await admin(); await sb.from('tdn_partenaires').delete().eq('id', id); chemins(); }

/** Attribue (ou retire) un lot à une clé, marque révélée / non révélée. */
export async function majCle(id: string, patch: { lot_id?: string | null; revelee?: boolean }) {
  const sb = await admin();
  const data: Partial<Cle> = {};
  if ('lot_id' in patch) data.lot_id = patch.lot_id ?? null;
  if ('revelee' in patch) data.revelee_le = patch.revelee ? new Date().toISOString() : null;
  await sb.from('tdn_cles').update(data).eq('id', id);
  chemins();
}

export async function marquerPaye(participantId: string, paye: boolean) {
  const sb = await admin();
  await sb.from('tdn_participants').update({ paye }).eq('id', participantId);
  chemins();
}

export async function supprimerParticipantAdmin(id: string) {
  const sb = await admin();
  await sb.from('tdn_participants').delete().eq('id', id);
  chemins();
}

export { numeroCle };


/* =========================================================
   TIRAGE DU GRAND TRÉSOR (écran admin)
   ========================================================= */
export type ResultatTirage = { ok: true; cleId: string; numero: number; prenom: string; famille: string; deja: boolean } | { ok: false; erreur: string };

/** Tire au sort une clé parmi toutes les clés générées, attribue le lot « grand trésor » et verrouille le résultat. */
export async function tirerGrandTresor(): Promise<ResultatTirage> {
  await admin();
  const db = createAdminClient();
  const { data: r } = await db.from('tdn_reglages').select('tirage_cle_id').eq('id', 1).single();
  const lireGagnant = async (id: string) => {
    const { data: c } = await db.from('tdn_cles').select('id, numero, tdn_participants(prenom, tdn_comptes(prenom, nom))').eq('id', id).single();
    const p = c?.tdn_participants as unknown as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { cleId: c!.id, numero: c!.numero, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '' };
  };
  if (r?.tirage_cle_id) return { ok: true, ...(await lireGagnant(r.tirage_cle_id)), deja: true };

  const { data: cles } = await db.from('tdn_cles').select('id');
  if (!cles || cles.length === 0) return { ok: false, erreur: 'Aucune clé générée : personne n’a terminé le jeu.' };
  const { data: grand } = await db.from('tdn_lots').select('id').eq('grand', true).order('position').limit(1).maybeSingle();
  if (!grand) return { ok: false, erreur: 'Aucun lot marqué « grand trésor » dans les lots.' };

  const gagnante = cles[Math.floor(Math.random() * cles.length)];
  const maintenant = new Date().toISOString();
  // Verrou : on n’écrit que si aucun tirage n’a été enregistré entre-temps.
  const { data: maj } = await db.from('tdn_reglages').update({ tirage_cle_id: gagnante.id, tirage_le: maintenant }).eq('id', 1).is('tirage_cle_id', null).select('tirage_cle_id').maybeSingle();
  if (!maj) { const { data: r2 } = await db.from('tdn_reglages').select('tirage_cle_id').eq('id', 1).single(); return { ok: true, ...(await lireGagnant(r2!.tirage_cle_id!)), deja: true }; }
  await db.from('tdn_cles').update({ lot_id: grand.id }).eq('id', gagnante.id);
  chemins();
  return { ok: true, ...(await lireGagnant(gagnante.id)), deja: false };
}

/** Annule le tirage (retire le grand trésor de la clé) pour pouvoir le relancer. */
export async function annulerTirage() {
  await admin();
  const db = createAdminClient();
  const { data: r } = await db.from('tdn_reglages').select('tirage_cle_id').eq('id', 1).single();
  if (r?.tirage_cle_id) await db.from('tdn_cles').update({ lot_id: null, revelee_le: null }).eq('id', r.tirage_cle_id);
  await db.from('tdn_reglages').update({ tirage_cle_id: null, tirage_le: null }).eq('id', 1);
  chemins();
}
