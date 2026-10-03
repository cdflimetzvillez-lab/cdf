'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout } from '@/lib/sumup';
import { commandeParId, lireReglagesPn, majCommande, referencePn } from '@/lib/pere-noel/db';
import { emailConfirmation, emailVideoPrete } from '@/lib/pere-noel/emails';
import { avancerCommande, traiterFile, verifierVideo } from '@/lib/pere-noel/pipeline';
import type { CommandePn, Sagesse, TonSecret } from '@/lib/pere-noel/types';

export type Etat = { ok?: string; erreur?: string } | null;

const emailValide = (e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
const txt = (fd: FormData, k: string, max = 1200) => String(fd.get(k) ?? '').trim().slice(0, max) || null;

/* =========================================================
   COMMANDE PUBLIQUE + PAIEMENT SUMUP
   ========================================================= */
export async function commander(_prev: Etat, fd: FormData): Promise<Etat> {
  const r = await lireReglagesPn();
  const { isAdmin } = await requireAdmin('pere-noel');
  const modeTest = fd.get('test') === '1' && isAdmin;
  if (!r.commandes_ouvertes && !modeTest) return { erreur: 'Les commandes ne sont pas ouvertes pour le moment.' };

  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const enfant = txt(fd, 'enfant_prenom', 40);
  if (!enfant) return { erreur: 'Le prénom de l’enfant est obligatoire.' };
  if (!emailValide(email)) return { erreur: 'Adresse email invalide.' };
  const age = Number(fd.get('age'));
  const sagesse = (['presque', 'tres_sage', 'le_plus_sage'].includes(String(fd.get('sagesse'))) ? String(fd.get('sagesse')) : 'tres_sage') as Sagesse;
  const ton = (['rigolo', 'tendre', 'serieux'].includes(String(fd.get('ton_secret'))) ? String(fd.get('ton_secret')) : 'rigolo') as TonSecret;
  const genreBrut = String(fd.get('genre') ?? '');
  const genre = genreBrut === 'fille' || genreBrut === 'garcon' ? genreBrut : null;
  const lettre = txt(fd, 'lettre', 1500);
  if (!lettre && !txt(fd, 'cadeaux', 300)) return { erreur: 'Écrivez au moins la lettre de l’enfant ou ce qu’il demande.' };

  const envoiPostal = r.envoi_postal_actif && fd.get('envoi_postal') === 'on';
  const adresse = {
    adresse_nom: txt(fd, 'adresse_nom', 80), adresse_ligne1: txt(fd, 'adresse_ligne1', 120), adresse_ligne2: txt(fd, 'adresse_ligne2', 120),
    adresse_cp: txt(fd, 'adresse_cp', 10), adresse_ville: txt(fd, 'adresse_ville', 80),
  };
  if (envoiPostal && (!adresse.adresse_nom || !adresse.adresse_ligne1 || !adresse.adresse_cp || !adresse.adresse_ville)) {
    return { erreur: 'Adresse postale incomplète (nom, adresse, code postal et ville).' };
  }

  const db = createAdminClient();
  const reference = referencePn();
  const montant = modeTest ? 0 : r.prix_centimes + (envoiPostal ? r.prix_postal_centimes : 0);
  const { data: cmd, error } = await db.from('pn_commandes').insert({
    reference, test: modeTest,
    parent_prenom: txt(fd, 'parent_prenom', 60) ?? '', email,
    enfant_prenom: enfant, prononciation: txt(fd, 'prononciation', 60),
    age: Number.isFinite(age) && age > 0 && age < 18 ? age : null, genre, sagesse,
    lettre, cadeaux: txt(fd, 'cadeaux', 300), fierte: txt(fd, 'fierte', 300), passion: txt(fd, 'passion', 300),
    effort: txt(fd, 'effort', 200), salut: txt(fd, 'salut', 120), secret: txt(fd, 'secret', 500), ton_secret: ton,
    envoi_postal: envoiPostal, ...(envoiPostal ? adresse : {}),
    montant_centimes: montant,
    statut: montant === 0 ? 'payee' : 'en_attente', paye_le: montant === 0 ? new Date().toISOString() : null,
  }).select('*').single();
  if (error || !cmd) { console.error('[pn commander]', error); return { erreur: 'Impossible d’enregistrer la commande.' }; }

  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  if (montant === 0) {
    await emailConfirmation(cmd as CommandePn, r);
    redirect(`/pere-noel/commander/retour?ref=${reference}`);
  }

  let url: string | undefined;
  try {
    const checkout = await creerCheckout({
      reference, montantCentimes: montant,
      description: `${reference} · Vidéo du Père Noël pour ${enfant}${envoiPostal ? ' + envoi postal' : ''}`,
      emailClient: email, urlRetour: `${base}/pere-noel/commander/retour?ref=${reference}`,
    });
    await db.from('pn_commandes').update({ checkout_id: checkout.id }).eq('id', cmd.id);
    url = checkout.hosted_checkout_url;
  } catch (e) {
    console.error('[pn commander] SumUp', e);
    await db.from('pn_commandes').update({ statut: 'echouee' }).eq('id', cmd.id);
    return { erreur: 'Le service de paiement est indisponible. Réessayez dans quelques minutes.' };
  }
  if (!url) return { erreur: 'Le paiement n’a pas pu être initialisé.' };
  redirect(url);
}

/** Synchronise une commande avec SumUp (retour de paiement ou webhook). Déclenche l'email et, si activé, la génération. */
export async function synchroniserCommandePn(reference?: string, checkoutId?: string): Promise<CommandePn | null> {
  const db = createAdminClient();
  const req = db.from('pn_commandes').select('*');
  const { data: cmd } = await (reference ? req.eq('reference', reference) : req.eq('checkout_id', checkoutId!)).maybeSingle();
  if (!cmd) return null;
  if (cmd.statut === 'payee' || !cmd.checkout_id) return cmd as CommandePn;

  try {
    const checkout = await lireCheckout(cmd.checkout_id);
    const corr: Record<string, string> = { PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente' };
    const statut = corr[checkout.status] ?? 'en_attente';
    if (statut === cmd.statut) return cmd as CommandePn;
    const { data: maj } = await db.from('pn_commandes').update({
      statut,
      transaction_code: checkout.transaction_code ?? checkout.transactions?.[0]?.transaction_code ?? null,
      paye_le: statut === 'payee' ? new Date().toISOString() : null,
    }).eq('id', cmd.id).select('*').single();
    if (statut === 'payee' && maj) {
      const r = await lireReglagesPn();
      await emailConfirmation(maj as CommandePn, r);
      if (r.generation_auto) avancerCommande(maj.id).catch((e) => console.error('[pn auto]', e));
    }
    return (maj ?? cmd) as CommandePn;
  } catch (e) {
    console.error('[synchroniserCommandePn]', e);
    return cmd as CommandePn;
  }
}

/** Depuis l'espace famille : si la vidéo est en cours chez HeyGen, on vérifie à chaque visite. */
export async function rafraichirDepuisEspace(id: string) {
  const c = await commandeParId(id);
  if (c && c.gen_statut === 'video') await verifierVideo(id);
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { isAdmin } = await requireAdmin('pere-noel');
  if (!isAdmin) throw new Error('Accès refusé.');
}
const chemins = () => { revalidatePath('/admin/pere-noel', 'layout'); revalidatePath('/pere-noel', 'layout'); revalidatePath('/'); };

export async function basculerModulePn(actif: boolean) {
  await admin();
  await createAdminClient().from('pn_reglages').update({ module_actif: actif }).eq('id', 1);
  chemins();
}

export async function majReglagesPn(_prev: Etat, fd: FormData): Promise<Etat> {
  await admin();
  const num = (k: string, def: number) => { const v = Number(fd.get(k)); return Number.isFinite(v) ? v : def; };
  const expr = String(fd.get('expressivite') ?? 'medium');
  const { error } = await createAdminClient().from('pn_reglages').update({
    titre: String(fd.get('titre') ?? '').trim() || 'Le Père Noël te répond',
    accroche: String(fd.get('accroche') ?? '').trim(),
    prix_centimes: Math.round(num('prix', 12.9) * 100),
    delai_texte: String(fd.get('delai_texte') ?? '').trim() || 'sous 48 h',
    commandes_ouvertes: fd.get('commandes_ouvertes') === 'on',
    generation_auto: fd.get('generation_auto') === 'on',
    relecture_script: fd.get('relecture_script') === 'on',
    image_url: String(fd.get('image_url') ?? '').trim() || null,
    video_demo_url: String(fd.get('video_demo_url') ?? '').trim() || null,
    envoi_postal_actif: fd.get('envoi_postal_actif') === 'on',
    prix_postal_centimes: Math.round(num('prix_postal', 4.9) * 100),
    voice_id: String(fd.get('voice_id') ?? '').trim() || null,
    modele_voix: String(fd.get('modele_voix') ?? '').trim() || 'eleven_multilingual_v2',
    stabilite: num('stabilite', 0.45), similarite: num('similarite', 0.75), style_voix: num('style_voix', 0.3), vitesse: num('vitesse', 0.92),
    expressivite: ['low', 'medium', 'high'].includes(expr) ? expr : 'medium',
    motion_prompt: String(fd.get('motion_prompt') ?? '').trim(),
    duree_cible_sec: Math.min(120, Math.max(30, Math.round(num('duree_cible_sec', 75)))),
    consignes_script: String(fd.get('consignes_script') ?? '').trim(),
    updated_at: new Date().toISOString(),
  }).eq('id', 1);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Réglages enregistrés.' };
}

/** Lance ou reprend la génération (script, audio, vidéo). */
export async function genererCommande(id: string) {
  await admin();
  await avancerCommande(id);
  chemins();
}

/** Valide (ou modifie) le script puis enchaîne audio et vidéo. */
export async function validerScript(_prev: Etat, fd: FormData): Promise<Etat> {
  await admin();
  const id = String(fd.get('id') ?? '');
  const script = String(fd.get('script') ?? '').trim();
  const lettre = String(fd.get('lettre_reponse') ?? '').trim();
  const mention = String(fd.get('certificat_mention') ?? '').trim();
  if (!id || script.length < 50) return { erreur: 'Script trop court.' };
  await majCommande(id, { script, lettre_reponse: lettre || null, certificat_mention: mention || null, audio_url: null, heygen_video_id: null, video_url: null, gen_statut: 'audio', erreur: null });
  const c = await avancerCommande(id, { ignorerRelecture: true });
  chemins();
  return c.gen_statut === 'erreur' ? { erreur: c.erreur ?? 'Erreur de génération.' } : { ok: 'Script validé, audio et vidéo lancés.' };
}

/** Régénère le script (le précédent est écrasé), retour en relecture. */
export async function regenererScript(id: string) {
  await admin();
  await majCommande(id, { script: null, lettre_reponse: null, certificat_mention: null, audio_url: null, heygen_video_id: null, video_url: null, gen_statut: 'a_faire', erreur: null });
  await avancerCommande(id);
  chemins();
}

/** Repart de zéro côté vidéo en gardant le script (ex. artefact HeyGen). */
export async function refaireVideo(id: string) {
  await admin();
  await majCommande(id, { heygen_video_id: null, video_url: null, duree_sec: null, email_envoye: false, gen_statut: 'audio', erreur: null });
  await avancerCommande(id, { ignorerRelecture: true });
  chemins();
}

export async function verifierCommande(id: string) {
  await admin();
  await verifierVideo(id);
  chemins();
}

export async function verifierToutes() {
  await admin();
  const res = await traiterFile(10);
  chemins();
  return res;
}

export async function renvoyerEmailVideo(id: string) {
  await admin();
  const c = await commandeParId(id);
  if (c?.video_url) { const ok = await emailVideoPrete(c); if (ok) await majCommande(id, { email_envoye: true }); }
  chemins();
}

export async function marquerPayee(id: string) {
  await admin();
  const c = await commandeParId(id);
  if (!c || c.statut === 'payee') return;
  await majCommande(id, { statut: 'payee', paye_le: new Date().toISOString() });
  const r = await lireReglagesPn();
  await emailConfirmation({ ...c, statut: 'payee' }, r);
  chemins();
}

export async function marquerExpedie(id: string, expedie: boolean) {
  await admin();
  await majCommande(id, { expedie_le: expedie ? new Date().toISOString() : null });
  chemins();
}

export async function supprimerCommande(id: string) {
  await admin();
  await createAdminClient().from('pn_commandes').delete().eq('id', id);
  chemins();
  redirect('/admin/pere-noel');
}
