#!/usr/bin/env bash
# Trésors de Noël :
#   1. La hotte du grand trésor montre les 3 cartes cadeaux (visuel dans public/tresors/carte-cadeau.webp).
#   2. Contient aussi la mise à jour « tirage unique à la révélation » (cartes tirées avec les autres lots,
#      une seule carte par compte, écran de tirage séparé supprimé, grand trésor affiché quand le jeu est ouvert).
# Aucun script SQL à exécuter.
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
rm -rf 'src/app/tresors-de-noel/tirage' 'src/components/tresors/Tirage.tsx'
mkdir -p 'public/tresors'
base64 --decode > 'public/tresors/carte-cadeau.webp' <<'EOF_PN_FICHIER'
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
wJlV3bFTYgewye8Cum6BfwBpmAgAAA==
EOF_PN_FICHIER
echo "  ✓ public/tresors/carte-cadeau.webp"
mkdir -p 'src/app/admin/(protected)/tresors/cles'
cat > 'src/app/admin/(protected)/tresors/cles/page.tsx' <<'EOF_PN_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import TableCles from '@/components/tresors/TableCles';
import type { Lot } from '@/lib/tresors/types';

export default async function AdminCles() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: cles }, { data: lots }] = await Promise.all([
    supabase.from('tdn_cles').select('*, tdn_participants(prenom, tdn_comptes(prenom, nom)), tdn_lots(nom, grand)').order('numero'),
    supabase.from('tdn_lots').select('*').order('position'),
  ]);
  const lignes = (cles ?? []).map((c) => {
    const p = c.tdn_participants as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, code: c.code, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '',
      lot_id: c.lot_id, lot: (c.tdn_lots as { nom: string } | null)?.nom ?? '', revelee: !!c.revelee_le };
  });
  const cartes = (cles ?? []).filter((c) => (c.tdn_lots as { grand?: boolean } | null)?.grand).length;
  const stockCartes = ((lots ?? []) as Lot[]).filter((l) => l.grand).reduce((s, l) => s + l.stock, 0);
  return (
    <>
      <div className="adm-h"><div><h1>Clés</h1><p>{lignes.length} clés générées · {lignes.filter((l) => l.revelee).length} révélées · {cartes} carte{cartes > 1 ? 's' : ''} du grand trésor sortie{cartes > 1 ? 's' : ''} sur {stockCartes}.</p></div></div>
      <div className="panel" style={{ borderLeft: '10px solid #FFD400' }}>
        <h2>Un seul tirage, à la révélation</h2>
        <p>Quand une clé est saisie sur l&apos;écran de révélation, son lot est tiré au sort parmi <b>tous les lots encore en stock, cartes du grand trésor comprises</b>. Un même compte ne peut remporter qu&apos;<b>une seule carte</b> : dès qu&apos;une de ses clés en a une, ses autres clés tirent parmi les autres lots.</p>
        <p style={{ marginTop: '.5rem', color: '#6b6560', fontSize: '.9rem' }}>Le tableau permet d&apos;imposer un lot à une clé avant sa révélation, ou de la remettre en « tirage au sort ». Une attribution faite à la main n&apos;est pas contrôlée par la règle « une carte par compte ».</p>
      </div>
      <TableCles lignes={lignes} lots={(lots ?? []) as Lot[]} />
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/cles/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors/lots'
cat > 'src/app/admin/(protected)/tresors/lots/page.tsx' <<'EOF_PN_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import GestionLots from '@/components/tresors/GestionLots';
import type { Lot, Partenaire } from '@/lib/tresors/types';

export default async function AdminLots() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: lots }, { data: partenaires }, { data: attribs }, { count: nbCles }] = await Promise.all([
    supabase.from('tdn_lots').select('*, tdn_partenaires(nom)').order('position'),
    supabase.from('tdn_partenaires').select('*').order('nom'),
    supabase.from('tdn_cles').select('lot_id, revelee_le').not('lot_id', 'is', null),
    supabase.from('tdn_cles').select('id', { count: 'exact', head: true }),
  ]);
  const compte: Record<string, { attribues: number; reveles: number }> = {};
  for (const a of attribs ?? []) {
    const c = (compte[a.lot_id!] ??= { attribues: 0, reveles: 0 });
    c.attribues++; if (a.revelee_le) c.reveles++;
  }
  // Urne de la révélation : un ticket par exemplaire en stock, cartes du grand trésor comprises.
  const liste = (lots ?? []) as Lot[];
  const stockTotal = liste.reduce((s, l) => s + l.stock, 0);
  const stockCartes = liste.filter((l) => l.grand).reduce((s, l) => s + l.stock, 0);
  const cles = nbCles ?? 0;
  const ecart = stockTotal - cles;
  return (
    <>
      <div className="adm-h"><div><h1>Lots et partenaires</h1><p>Tous les lots, cartes du « grand trésor » comprises, sont tirés au sort dans la même urne au moment de la révélation, dans la limite du stock. Un compte ne peut remporter qu&apos;une seule carte du grand trésor.</p></div></div>
      <div className="panel" style={{ borderLeft: `10px solid ${ecart === 0 ? '#9BD44F' : '#FFD400'}` }}>
        <h2>Stock et clés</h2>
        <p><b>{stockTotal}</b> lot{stockTotal > 1 ? 's' : ''} en stock, dont <b>{stockCartes}</b> carte{stockCartes > 1 ? 's' : ''} du grand trésor · <b>{cles}</b> clé{cles > 1 ? 's' : ''} générée{cles > 1 ? 's' : ''}.</p>
        {ecart > 0 && <p style={{ marginTop: '.5rem' }}>Il y a <b>{ecart} lot{ecart > 1 ? 's' : ''} de plus que de clés</b>. Ce n&apos;est pas bloquant, mais {ecart > 1 ? `${ecart} lots resteront` : 'un lot restera'} dans l&apos;urne à la fin, et ce peut être une carte du grand trésor. Pour que toutes les cartes sortent, ajustez le stock des autres lots au nombre de clés une fois le jeu terminé, avant d&apos;ouvrir la révélation.</p>}
        {ecart < 0 && <p style={{ marginTop: '.5rem' }}>Il manque <b>{-ecart} lot{ecart < -1 ? 's' : ''}</b> : les dernières clés révélées n&apos;auraient plus rien à tirer. Ajoutez du stock.</p>}
        {ecart === 0 && cles > 0 && <p style={{ marginTop: '.5rem' }}>Autant de lots que de clés : si toutes les clés sont révélées, tous les lots sortent, cartes comprises.</p>}
      </div>
      <GestionLots lots={liste} partenaires={(partenaires ?? []) as Partenaire[]} compte={compte} />
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/lots/page.tsx"
mkdir -p 'src/app/admin/(protected)/tresors'
cat > 'src/app/admin/(protected)/tresors/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import BasculeModuleTdn from '@/components/tresors/BasculeModuleTdn';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import type { Stats } from '@/lib/tresors/types';

export default async function AdminTresors() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: stats }, { data: reglages }, { count: nbMissions }, { count: nbLots }] = await Promise.all([
    supabase.from('tdn_stats').select('*').single(),
    supabase.from('tdn_reglages').select('*').eq('id', 1).single(),
    supabase.from('tdn_missions').select('id', { count: 'exact', head: true }),
    supabase.from('tdn_lots').select('id', { count: 'exact', head: true }),
  ]);
  const s = (stats ?? {}) as Partial<Stats>;

  return (
    <>
      <div className="adm-h">
        <div><h1>Trésors de Noël</h1><p>Chasse aux trésors du Marché de Noël.</p></div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          <Link className="btn btn-w btn-sm" href="/tresors-de-noel" target="_blank">↗ Page du jeu</Link>
          <Link className="btn btn-w btn-sm" href="/tresors-de-noel/reglement" target="_blank">↗ Règlement</Link>
          <Link className="btn btn-y btn-sm" href="/tresors-de-noel/revelation" target="_blank">↗ Écran de révélation</Link>
        </div>
      </div>

      <BasculeModuleTdn actif={reglages?.module_actif !== false} />
      <div className="kpi">
        <div><b>{s.inscrits ?? 0} / {reglages?.places_max ?? '—'}</b><span>Places réservées</span></div>
        <div><b>{euros(s.ca_centimes ?? 0)}</b><span>Chiffre d&apos;affaires</span></div>
        <div><b>{s.commences ?? 0}</b><span>Ont commencé</span></div>
        <div><b>{s.termines ?? 0}</b><span>Ont terminé</span></div>
        <div><b>{s.cles_generees ?? 0}</b><span>Clés générées</span></div>
        <div><b>{s.cles_revelees ?? 0}</b><span>Clés révélées</span></div>
      </div>

      <div className="row2">
        <div className="panel">
          <h2>État</h2>
          <p>Inscriptions : <span className={`pill ${reglages?.inscriptions_ouvertes ? 'on' : 'off'}`}>{reglages?.inscriptions_ouvertes ? 'ouvertes' : 'fermées'}</span></p>
          <p style={{ marginTop: '.5rem' }}>Jeu : <span className={`pill ${reglages?.jeu_actif ? 'on' : 'off'}`}>{reglages?.jeu_actif ? 'activé' : 'désactivé'}</span> · du {reglages?.jeu_debut ? new Date(reglages.jeu_debut).toLocaleDateString('fr-FR') : '—'} au {reglages?.jeu_fin ? new Date(reglages.jeu_fin).toLocaleDateString('fr-FR') : '—'}</p>
          <p style={{ marginTop: '.5rem' }}>{nbMissions ?? 0} missions · {nbLots ?? 0} lots</p>
          <Link className="btn btn-y btn-sm" href="/admin/tresors/reglages" style={{ marginTop: '1rem' }}>Modifier les réglages</Link>
        </div>
        <div className="panel">
          <h2>Raccourcis</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '.6rem', alignItems: 'flex-start' }}>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/missions/nouvelle">+ Nouvelle mission</Link>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/lots">Gérer les lots</Link>
            <Link className="btn btn-w btn-sm" href="/admin/tresors/cles">Clés et lots attribués</Link>
          </div>
        </div>
      </div>
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/admin/(protected)/tresors/page.tsx"
mkdir -p 'src/app'
cat > 'src/app/tresors-actions.ts' <<'EOF_PN_FICHIER'
'use server';

import { randomInt } from 'node:crypto';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout } from '@/lib/sumup';
import { COOKIE_ACTIF, COOKIE_TOKEN, compteCourant, jeuOuvert, lireMissions, lireReglages, placesPrises } from '@/lib/tresors/db';
import type { Categorie, Cle, Lot, Mission, Bloc } from '@/lib/tresors/types';

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

/* Règle d'inscription : aucun enfant sans au moins un adulte inscrit sur le même compte. */
const MSG_ADULTE = 'Au moins un adulte doit être inscrit pour pouvoir inscrire des enfants.';
const estAdulte = (p: { categorie: string }) => p.categorie === 'adulte';
const estEnfant = (p: { categorie: string }) => p.categorie !== 'adulte';

/** Le compte compte-t-il déjà un adulte ? (payeSeulement : uniquement ceux dont la participation est réglée) */
async function compteAUnAdulte(compteId: string, payeSeulement = false) {
  const db = createAdminClient();
  let req = db.from('tdn_participants').select('id', { count: 'exact', head: true }).eq('compte_id', compteId).eq('categorie', 'adulte');
  if (payeSeulement) req = req.eq('paye', true);
  const { count } = await req;
  return (count ?? 0) > 0;
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

  // Compte : réutilise celui du cookie si présent, sinon il sera créé plus bas.
  const existant = await compteCourant();
  // Pas d'enfant sans adulte : un adulte dans cette inscription, ou déjà réglé sur le compte.
  if (lignes.some(estEnfant) && !lignes.some(estAdulte) && !(existant && (await compteAUnAdulte(existant.id, true)))) return { erreur: MSG_ADULTE };

  const restantes = reglages.places_max - (await placesPrises());
  if (restantes <= 0) return { erreur: 'Complet : toutes les places ont été réservées.' };
  if (lignes.length > restantes) return { erreur: `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}. Réduisez le nombre de participants.` };

  const db = createAdminClient();

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
  // Pas d'enfant sans adulte : un adulte dans ce paiement, ou déjà réglé sur le compte.
  if (parts.some(estEnfant) && !parts.some(estAdulte) && !(await compteAUnAdulte(compte.id, true))) {
    return { erreur: `${MSG_ADULTE} Ajoutez un adulte avant de régler.` };
  }
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
  if (categorie === 'enfant' && !(await compteAUnAdulte(compte.id))) return { erreur: `${MSG_ADULTE} Ajoutez d’abord un adulte.` };
  const db = createAdminClient();
  await db.from('tdn_participants').insert({ compte_id: compte.id, prenom, categorie, paye: false });
  revalidatePath('/tresors-de-noel', 'layout');
  return { ok: `${prenom} ajouté. Réglez sa participation pour l’activer.` };
}

export async function supprimerParticipant(id: string): Promise<Etat> {
  const compte = await compteCourant();
  if (!compte) return { erreur: 'Non connecté.' };
  const db = createAdminClient();
  const { data: parts } = await db.from('tdn_participants').select('id, categorie, paye').eq('compte_id', compte.id);
  const cible = (parts ?? []).find((p) => p.id === id);
  // On ne supprime que les participants non payés du compte courant.
  if (!cible || cible.paye) return null;
  // Le dernier adulte ne peut pas être retiré tant que des enfants attendent leur inscription.
  if (estAdulte(cible)) {
    const autres = (parts ?? []).filter((p) => p.id !== id);
    if (autres.some((p) => estEnfant(p) && !p.paye) && !autres.some(estAdulte)) {
      return { erreur: 'Impossible de retirer le seul adulte tant que des enfants sont inscrits. Retirez d’abord les enfants, ou ajoutez un autre adulte.' };
    }
  }
  await db.from('tdn_participants').delete().eq('id', id).eq('compte_id', compte.id).eq('paye', false);
  revalidatePath('/tresors-de-noel', 'layout');
  return null;
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
   Tirage unique : tous les lots encore en stock sont dans la même urne, cartes du grand trésor
   comprises. Seule règle : une seule carte du grand trésor par compte.
   ========================================================= */
type Db = ReturnType<typeof createAdminClient>;

/** Lots marqués « grand trésor » et clés du compte qui en détiennent déjà un (autres que la clé donnée). */
async function cartesDuCompte(db: Db, compteId: string | null, cleId: string) {
  const { data: grands } = await db.from('tdn_lots').select('id').eq('grand', true);
  const idsGrands = (grands ?? []).map((l) => l.id as string);
  if (!compteId || idsGrands.length === 0) return { idsGrands, autres: [] as string[] };
  const { data: parts } = await db.from('tdn_participants').select('id').eq('compte_id', compteId);
  const idsParts = (parts ?? []).map((x) => x.id as string);
  if (idsParts.length === 0) return { idsGrands, autres: [] as string[] };
  const { data: cles } = await db.from('tdn_cles').select('id, lot_id').in('participant_id', idsParts).in('lot_id', idsGrands);
  return { idsGrands, autres: (cles ?? []).map((c) => c.id as string).filter((id) => id !== cleId) };
}

/** Tire un lot dans l'urne : un ticket par exemplaire restant en stock. Renvoie null si l'urne est vide. */
async function tirerLot(db: Db, sansGrand: boolean): Promise<string | null> {
  const [{ data: lots }, { data: attribs }] = await Promise.all([
    db.from('tdn_lots').select('id, stock, grand'),
    db.from('tdn_cles').select('lot_id').not('lot_id', 'is', null),
  ]);
  const pris: Record<string, number> = {};
  for (const a of attribs ?? []) pris[a.lot_id as string] = (pris[a.lot_id as string] ?? 0) + 1;
  const urne: string[] = [];
  for (const l of lots ?? []) {
    if (l.grand && sansGrand) continue;
    for (let i = pris[l.id] ?? 0; i < l.stock; i++) urne.push(l.id as string);
  }
  return urne.length > 0 ? urne[randomInt(urne.length)] : null;
}

export async function reveler(numero: string, code: string): Promise<{ lot?: Lot; prenom?: string; dejaRevelee?: boolean; erreur?: string }> {
  const n = Number(numero.trim());
  const c = code.trim().toUpperCase();
  if (!n || !c) return { erreur: 'Clé incomplète.' };
  const db = createAdminClient();
  const { data: cle } = await db.from('tdn_cles').select('*, tdn_participants(prenom, compte_id)').eq('numero', n).eq('code', c).maybeSingle();
  if (!cle) return { erreur: 'Clé inconnue. Vérifiez le numéro et le code secret.' };
  const participant = (cle as { tdn_participants?: { prenom: string; compte_id: string } | null }).tdn_participants ?? null;
  const dejaRevelee = !!cle.revelee_le;
  const maintenant = new Date().toISOString();

  let lotId: string | null = cle.lot_id;
  if (lotId) {
    // Lot déjà attribué (révélation précédente ou attribution manuelle) : on ne retire jamais au sort.
    if (!cle.revelee_le) await db.from('tdn_cles').update({ revelee_le: maintenant }).eq('id', cle.id);
  } else {
    const compteId = participant?.compte_id ?? null;
    const { idsGrands, autres } = await cartesDuCompte(db, compteId, cle.id);
    const tire = await tirerLot(db, autres.length > 0);
    if (!tire) return { erreur: 'Plus aucun lot disponible. Adressez-vous aux bénévoles.' };
    // On n'écrit que si la clé n'a toujours pas de lot (deux écrans sur la même clé en même temps).
    const { data: ecrit } = await db.from('tdn_cles').update({ lot_id: tire, revelee_le: maintenant }).eq('id', cle.id).is('lot_id', null).select('lot_id').maybeSingle();
    if (ecrit) {
      lotId = tire;
      // Deux clés d'un même compte révélées au même instant : une seule garde la carte, l'autre retire parmi les autres lots.
      if (idsGrands.includes(tire)) {
        const { autres: rivales } = await cartesDuCompte(db, compteId, cle.id);
        if (rivales.some((id) => id < cle.id)) {
          const autreLot = await tirerLot(db, true);
          if (!autreLot) {
            await db.from('tdn_cles').update({ lot_id: null, revelee_le: null }).eq('id', cle.id);
            return { erreur: 'Plus aucun lot disponible. Adressez-vous aux bénévoles.' };
          }
          await db.from('tdn_cles').update({ lot_id: autreLot }).eq('id', cle.id);
          lotId = autreLot;
        }
      }
    } else {
      const { data: relue } = await db.from('tdn_cles').select('lot_id').eq('id', cle.id).single();
      lotId = relue?.lot_id ?? null;
      if (!lotId) return { erreur: 'Révélation impossible pour le moment. Réessayez.' };
    }
  }
  const { data: lot } = await db.from('tdn_lots').select('*, tdn_partenaires(nom)').eq('id', lotId).single();
  if (!lot) return { erreur: 'Lot introuvable. Adressez-vous aux bénévoles.' };
  return { lot: lot as Lot, prenom: participant?.prenom, dejaRevelee };
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { supabase, isAdmin } = await requireAdmin('tresors');
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


/** Interrupteur général : retire le module du menu et des pages publiques (les données sont conservées). */
export async function basculerModuleTdn(actif: boolean) {
  const sb = await admin();
  await sb.from('tdn_reglages').update({ module_actif: actif }).eq('id', 1);
  chemins();
  revalidatePath('/');
  revalidatePath('/evenements', 'layout');
}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-actions.ts"
mkdir -p 'src/app/tresors-de-noel'
cat > 'src/app/tresors-de-noel/page.tsx' <<'EOF_PN_FICHIER'
import Accueil from '@/components/tresors/Accueil';
import { compteCourant, jeuOuvert, lireReglagesPublics, placesPrises } from '@/lib/tresors/db';

export default async function PageTresors() {
  const [reglages, compte] = await Promise.all([lireReglagesPublics(), compteCourant()]);
  const ouvert = jeuOuvert(reglages);
  const prises = ouvert ? 0 : await placesPrises();
  return <Accueil reglages={reglages} connecte={!!compte} phase={ouvert ? 'jeu' : 'reservation'} placesRestantes={Math.max(reglages.places_max - prises, 0)} />;
}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-de-noel/page.tsx"
mkdir -p 'src/app/tresors-de-noel/reglement'
cat > 'src/app/tresors-de-noel/reglement/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import type { Metadata } from 'next';
import Entete from '@/components/tresors/Entete';
import { createClient } from '@/lib/supabase/server';
import { dateFr, lireLots, lireMissions, lireReglages } from '@/lib/tresors/db';
import { euros } from '@/lib/sumup';
import { enLettres, nombreGrandTresor } from '@/lib/tresors/types';
import type { SiteSettings } from '@/lib/types';

export const metadata: Metadata = { title: 'Règlement · Les Trésors de Noël de Limetz-Villez' };

export default async function PageReglementTdn() {
  const supabase = await createClient();
  const [{ data: settings }, r, lots, missions] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(), lireReglages(), lireLots(), lireMissions(),
  ]);
  const s = settings as SiteSettings;
  const site = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://cdf-limetzvillez.fr';
  const nbMissions = missions.length || 12;
  // Grand trésor : une ou plusieurs cartes cadeaux identiques, une clé gagnante par carte.
  // Nombre de cartes réellement mises en jeu : le stock des lots marqués « grand trésor ».
  const nbGrand = lots.filter((l) => l.grand).reduce((n, l) => n + l.stock, 0) || nombreGrandTresor(r);
  const nbGrandTexte = `${enLettres(nbGrand)} (${nbGrand})`;
  // Regroupe les lots par nom (évite les doublons) et additionne les stocks.
  const autresLots = Object.values(
    lots.filter((l) => !l.grand).reduce<Record<string, { nom: string; partenaire: string | null; quantite: number }>>((acc, l) => {
      const k = l.nom.trim().toLowerCase();
      acc[k] ??= { nom: l.nom.trim(), partenaire: l.tdn_partenaires?.nom ?? null, quantite: 0 };
      acc[k].quantite += l.stock;
      return acc;
    }, {})
  );

  return (
    <main className="tdn-page tdn-reglement" style={{ maxWidth: '44rem' }}>
      <Entete titre="Règlement du jeu" sur={r.titre} />
      <p className="tdn-muted" style={{ marginBottom: '2rem' }}>Version en vigueur au {dateFr(new Date().toISOString())}. Ce règlement est accessible pendant toute la durée de l&apos;opération à l&apos;adresse {site}/tresors-de-noel/reglement.</p>

      <h2>Article 1 · Organisateur</h2>
      <p>Le jeu « {r.titre} » (ci-après « le Jeu ») est organisé par le Comité des Fêtes de Limetz-Villez, association régie par la loi du 1er juillet 1901, dont le siège est situé {s.adresse}, joignable à l&apos;adresse {s.email_contact} (ci-après « l&apos;Organisateur »).</p>

      <h2>Article 2 · Nature et durée du Jeu</h2>
      <p>Le Jeu est une chasse aux trésors se déroulant sur la voie publique de la commune de Limetz-Villez, à l&apos;aide d&apos;une application web accessible depuis un smartphone à l&apos;adresse {site}/tresors-de-noel.</p>
      <p>Le Jeu se déroule du {dateFr(r.jeu_debut, true)} au {dateFr(r.jeu_fin, true)} (heure de Paris). La révélation des lots a lieu lors du {r.marche_texte}, à {r.lieu_revelation}.</p>
      <p>Les inscriptions sont ouvertes avant le début du Jeu et peuvent se poursuivre pendant celui-ci, dans la limite des places disponibles. L&apos;Organisateur se réserve le droit d&apos;écourter, de prolonger, de suspendre ou d&apos;annuler le Jeu, notamment en cas de force majeure, d&apos;intempéries rendant le parcours dangereux ou de dysfonctionnement technique majeur. Dans ce cas, les participants seront informés par e-mail et les participations remboursées si le Jeu ne peut avoir lieu.</p>

      <h2>Article 3 · Conditions de participation</h2>
      <p>Le Jeu est ouvert à toute personne physique. Les mineurs participent sous la responsabilité et avec l&apos;accord d&apos;un représentant légal, qui crée le compte et effectue l&apos;inscription. Les mineurs de moins de 12 ans doivent être accompagnés d&apos;un adulte pendant tout le parcours. <b>Aucun enfant ne peut être inscrit seul</b> : l&apos;inscription d&apos;un ou plusieurs enfants n&apos;est possible que si au moins un adulte est inscrit comme participant sur le même compte.</p>
      <p>La participation est <b>individuelle et payante</b> : chaque participant, adulte ou enfant, doit être inscrit nommément. Le tarif est de {euros(r.tarif_adulte_centimes)} par adulte et {euros(r.tarif_enfant_centimes)} par enfant (moins de 18 ans). Un même compte, géré par un responsable majeur, peut regrouper plusieurs participants d&apos;une même famille ou d&apos;un même groupe.</p>
      <p>Le nombre de participants est limité à <b>{r.places_max}</b>. Les inscriptions sont enregistrées dans l&apos;ordre des paiements validés ; une fois ce nombre atteint, les inscriptions sont closes. Les membres du bureau de l&apos;Organisateur et les personnes ayant participé à la conception des énigmes ne peuvent pas participer.</p>

      <h2>Article 4 · Inscription et paiement</h2>
      <p>L&apos;inscription s&apos;effectue en ligne. Le responsable renseigne ses coordonnées (prénom, nom, adresse e-mail, téléphone facultatif), inscrit les participants (prénom, catégorie adulte ou enfant ; au moins un adulte dès lors qu&apos;un enfant est inscrit) et règle le montant total par carte bancaire via le prestataire de paiement SumUp. L&apos;Organisateur n&apos;a jamais accès aux données bancaires.</p>
      <p>L&apos;inscription est définitive à réception du paiement. Un e-mail de confirmation est envoyé au responsable. Conformément à l&apos;article L221-28 du Code de la consommation, les prestations de loisirs fournies à une date déterminée ne sont pas soumises au droit de rétractation : <b>aucun remboursement</b> n&apos;est effectué en cas de désistement, de non-participation ou d&apos;abandon en cours de Jeu, sauf annulation du Jeu par l&apos;Organisateur.</p>
      <p>Les sommes perçues financent les lots et l&apos;organisation de l&apos;événement.</p>

      <h2>Article 5 · Déroulement du Jeu</h2>
      <p>Le Jeu comporte {nbMissions} missions correspondant à des lieux du village. Pour chaque mission, le participant se rend sur place, observe le lieu et répond à une question sur l&apos;application. Une bonne réponse valide la mission et débloque la suivante. Les missions se font dans l&apos;ordre.</p>
      <p>Les participants d&apos;un même compte peuvent jouer ensemble sur un seul smartphone : le responsable valide chaque mission pour les participants présents. Chaque participant conserve néanmoins sa progression et sa clé individuelles.</p>
      <p>Des indices, puis une solution de secours, sont proposés pour chaque mission. Leur utilisation n&apos;entraîne aucune pénalité. Le Jeu peut être réalisé en une ou plusieurs fois, à toute heure, pendant la durée du Jeu ; la progression est sauvegardée sur le compte.</p>
      <p>Lorsqu&apos;un participant a validé l&apos;ensemble des missions, une <b>clé virtuelle</b> individuelle (numéro et code secret) est générée sur son compte. Cette clé est strictement personnelle. Aucune clé n&apos;est générée après la clôture du Jeu.</p>

      <h2>Article 6 · Dotations</h2>
      <p><b>Chaque participant ayant obtenu sa clé virtuelle reçoit un lot</b>, dans les conditions de l&apos;article 7. Tous les lots, y compris le grand trésor, sont attribués par un tirage au sort informatique unique : au moment où une clé est révélée, son lot est tiré au sort parmi l&apos;ensemble des lots encore disponibles.</p>
      {nbGrand > 1 ? (
        <p>Le <b>grand trésor</b> est composé de <b>{nbGrandTexte} cartes cadeaux multi-enseignes d&apos;une valeur unitaire de {r.grand_tresor_montant}</b>, utilisables dans l&apos;ensemble des enseignes partenaires de l&apos;émetteur. Ces cartes font partie des lots mis en jeu lors de la révélation. <b>Un même compte ne peut remporter qu&apos;une seule carte cadeau du grand trésor</b> : lorsqu&apos;une clé d&apos;un compte a remporté une carte, les autres clés de ce compte sont tirées au sort parmi les autres lots.</p>
      ) : (
        <p>Le <b>grand trésor</b> est une carte cadeau multi-enseignes d&apos;une valeur de {r.grand_tresor_montant}, utilisable dans l&apos;ensemble des enseignes partenaires de l&apos;émetteur. Cette carte fait partie des lots mis en jeu lors de la révélation.</p>
      )}
      <p>Les lots qui n&apos;auraient pas été attribués à l&apos;issue de la révélation et du délai de retrait prévu à l&apos;article 7, y compris une carte cadeau du grand trésor, restent acquis à l&apos;Organisateur.</p>
      <p>Les autres lots mis en jeu sont les suivants, dans la limite des quantités indiquées :</p>
      <ul className="tdn-reglement-lots">
        {autresLots.map((l) => <li key={l.nom}><b>{l.nom}</b>{l.partenaire && ` (offert par ${l.partenaire})`} : {l.quantite} exemplaire{l.quantite > 1 ? 's' : ''}</li>)}
        {autresLots.length === 0 && <li>Liste à venir.</li>}
      </ul>
      <p>La valeur des lots est indicative. L&apos;Organisateur se réserve la possibilité de remplacer un lot par un lot de valeur équivalente ou supérieure, notamment en cas d&apos;indisponibilité chez un partenaire.</p>
      <p>Les lots ne peuvent être échangés contre leur valeur en espèces ni contre un autre lot. Ils sont nominatifs et non cessibles. Un participant ne peut recevoir qu&apos;un seul lot par clé.</p>

      <h2>Article 7 · Révélation et remise des lots</h2>
      <p>La révélation a lieu lors du {r.marche_texte}, à {r.lieu_revelation}. Le participant, ou son responsable, saisit son numéro de clé et son code secret sur l&apos;écran de la Salle aux Trésors ; le lot lui est alors attribué et affiché. Il le retire immédiatement auprès des bénévoles, sur présentation de l&apos;écran et, sur demande, d&apos;une pièce d&apos;identité du responsable.</p>
      <p>Une clé ne peut être révélée qu&apos;une seule fois. Les participants absents à la révélation peuvent retirer leur lot auprès de l&apos;Organisateur, sur rendez-vous, dans un délai de <b>30 jours</b> suivant la révélation, en présentant leur clé. Passé ce délai, le lot reste acquis à l&apos;Organisateur. Les frais éventuels de déplacement ou d&apos;envoi restent à la charge du gagnant.</p>

      <h2>Article 8 · Comportement et sécurité</h2>
      <p>Le Jeu se déroule sur la voie publique, sans encadrement. Chaque participant, ou le représentant légal d&apos;un mineur, est responsable de sa propre sécurité : respect du Code de la route, prudence aux abords des routes, de la Seine et des cours d&apos;eau, équipement adapté à la météo et à la nuit tombante.</p>
      <p>Les énigmes se résolvent par simple observation. Il est interdit de pénétrer dans une propriété privée, de déplacer, dégrader ou emporter quoi que ce soit, de gêner les riverains ou la circulation. Tout comportement contraire entraîne l&apos;exclusion immédiate, sans remboursement, et engage la responsabilité de son auteur.</p>
      <p>L&apos;Organisateur décline toute responsabilité en cas d&apos;accident, de perte, de vol ou de dommage survenant pendant le parcours. Les participants sont invités à vérifier qu&apos;ils bénéficient d&apos;une assurance responsabilité civile.</p>

      <h2>Article 9 · Fraude</h2>
      <p>Sont notamment interdits : le partage des réponses ou des clés avec des personnes non inscrites, la validation de missions pour des participants absents, l&apos;utilisation de plusieurs comptes, toute tentative d&apos;accès non autorisé à l&apos;application ou de contournement de ses mécanismes. L&apos;Organisateur peut annuler la clé et la participation de tout contrevenant, sans remboursement, et se réserve le droit d&apos;engager des poursuites.</p>
      <p>Les réponses sont vérifiées par le serveur de l&apos;application. Les décisions de l&apos;Organisateur concernant la validité d&apos;une participation, d&apos;une clé ou d&apos;une attribution de lot sont sans appel.</p>

      <h2>Article 10 · Données personnelles</h2>
      <p>Les données collectées (coordonnées du responsable, prénoms et catégories des participants, progression, clés, informations de paiement transmises au prestataire SumUp) sont nécessaires à la gestion des inscriptions, du Jeu et de la remise des lots. Elles sont traitées par l&apos;Organisateur, responsable de traitement, sur la base de l&apos;exécution du contrat d&apos;inscription, et hébergées chez des prestataires établis dans l&apos;Union européenne ou offrant des garanties équivalentes.</p>
      <p>Elles sont conservées jusqu&apos;à trois mois après la révélation, puis supprimées, à l&apos;exception des données comptables conservées pendant la durée légale. Un cookie technique, sans finalité publicitaire, permet de retrouver le compte sur le téléphone utilisé. Conformément au Règlement (UE) 2016/679, vous disposez d&apos;un droit d&apos;accès, de rectification, d&apos;effacement, de limitation et d&apos;opposition, à exercer auprès de {s.email_contact}. Vous pouvez introduire une réclamation auprès de la CNIL.</p>

      <h2>Article 11 · Droit à l&apos;image</h2>
      <p>Des photographies et vidéos peuvent être réalisées lors de la révélation. En participant à cette cérémonie, les participants et leurs représentants légaux autorisent l&apos;Organisateur à les utiliser, sans contrepartie, sur ses supports de communication (site, réseaux sociaux, bulletin municipal) pendant deux ans. Toute personne peut s&apos;y opposer en le signalant sur place ou par e-mail.</p>

      <h2>Article 12 · Propriété intellectuelle</h2>
      <p>Les énigmes, textes, visuels et l&apos;application sont la propriété de l&apos;Organisateur ou de ses partenaires. Toute reproduction ou diffusion, notamment des énigmes et de leurs réponses, est interdite pendant la durée du Jeu.</p>

      <h2>Article 13 · Acceptation et litiges</h2>
      <p>L&apos;inscription au Jeu implique l&apos;acceptation pleine et entière du présent règlement, ainsi que des décisions de l&apos;Organisateur relatives à son application. Toute contestation doit être adressée par écrit à l&apos;Organisateur dans un délai de 15 jours suivant la révélation. Le présent règlement est soumis au droit français ; à défaut d&apos;accord amiable, les tribunaux compétents sont ceux du ressort du siège de l&apos;Organisateur.</p>

      <p style={{ marginTop: '2.5rem' }}><Link href="/tresors-de-noel" className="tdn-btn tdn-btn-ghost">← Retour</Link></p>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-de-noel/reglement/page.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/FormReglagesTdn.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState } from 'react';
import { majReglagesTdn, type Etat } from '@/app/tresors-actions';
import type { Reglages } from '@/lib/tresors/types';

function local(iso: string | null) {
  if (!iso) return '';
  const p = new Intl.DateTimeFormat('fr-FR', { timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: false })
    .formatToParts(new Date(iso)).reduce<Record<string, string>>((a, x) => (a[x.type] = x.value, a), {});
  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}

export default function FormReglagesTdn({ r }: { r: Reglages }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(majReglagesTdn, null);
  return (
    <form action={action}>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="panel">
        <h2>Textes</h2>
        <div className="field"><label htmlFor="titre">Titre de l&apos;événement</label><input id="titre" name="titre" defaultValue={r.titre} /></div>
        <div className="field"><label htmlFor="accroche">Accroche</label><input id="accroche" name="accroche" defaultValue={r.accroche} /></div>
        <div className="row3">
          <div className="field"><label htmlFor="periode_texte">Période du jeu</label><input id="periode_texte" name="periode_texte" defaultValue={r.periode_texte} /></div>
          <div className="field"><label htmlFor="marche_texte">Marché de Noël (révélation)</label><input id="marche_texte" name="marche_texte" defaultValue={r.marche_texte} /></div>
          <div className="field"><label htmlFor="duree_texte">Durée annoncée</label><input id="duree_texte" name="duree_texte" defaultValue={r.duree_texte} /></div>
        </div>
      </div>
      <div className="panel">
        <h2>Tarifs et ouverture</h2>
        <div className="row2">
          <div className="field"><label htmlFor="tarif_adulte">Tarif adulte (€)</label><input id="tarif_adulte" name="tarif_adulte" type="number" step="0.5" min={0} defaultValue={r.tarif_adulte_centimes / 100} /></div>
          <div className="field"><label htmlFor="tarif_enfant">Tarif enfant (€)</label><input id="tarif_enfant" name="tarif_enfant" type="number" step="0.5" min={0} defaultValue={r.tarif_enfant_centimes / 100} /></div>
        </div>
        <div className="field"><label htmlFor="places_max">Nombre de places (participants payés maximum)</label><input id="places_max" name="places_max" type="number" min={0} defaultValue={r.places_max} /></div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="inscriptions_ouvertes" defaultChecked={r.inscriptions_ouvertes} style={{ width: 'auto' }} /> Réservations ouvertes</label>
      </div>
      <div className="panel">
        <h2>Période du jeu</h2>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="jeu_actif" defaultChecked={r.jeu_actif} style={{ width: 'auto' }} /> Jeu activé (interrupteur général)</label>
        <div className="row2">
          <div className="field"><label htmlFor="jeu_debut">Début du jeu (heure de Paris)</label><input id="jeu_debut" name="jeu_debut" type="datetime-local" defaultValue={local(r.jeu_debut)} /></div>
          <div className="field"><label htmlFor="jeu_fin">Fin du jeu</label><input id="jeu_fin" name="jeu_fin" type="datetime-local" defaultValue={local(r.jeu_fin)} /></div>
        </div>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Avant le début : la page du jeu affiche la réservation des places. Pendant : le jeu. Après la fin : plus aucune mission ne peut être validée.</p>
      </div>
      <div className="panel">
        <h2>Grand trésor et révélation</h2>
        <div className="row2">
          <div className="field"><label htmlFor="grand_tresor_montant">Montant d&apos;une carte</label><input id="grand_tresor_montant" name="grand_tresor_montant" defaultValue={r.grand_tresor_montant} placeholder="100 €" /></div>
          <div className="field"><label htmlFor="grand_tresor_texte">Description</label><input id="grand_tresor_texte" name="grand_tresor_texte" defaultValue={r.grand_tresor_texte} placeholder="3 cartes cadeaux multi-enseignes" /></div>
        </div>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginBottom: '1rem' }}>Le nombre de cartes mises en jeu est le <b>stock du lot marqué « grand trésor »</b> (onglet Lots) : avec un stock de 3 et un montant de 100 €, la page du jeu affiche « 3 × 100 € ». Les cartes sont tirées au sort à la révélation, avec les autres lots.</p>
        <div className="field"><label htmlFor="lieu_revelation">Lieu de la révélation (règlement)</label><input id="lieu_revelation" name="lieu_revelation" defaultValue={r.lieu_revelation} /></div>
      </div>
      <button className="btn btn-k" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer'}</button>
    </form>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/FormReglagesTdn.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/GestionLots.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState, useState, useTransition } from 'react';
import { enregistrerLot, enregistrerPartenaire, supprimerLot, supprimerPartenaire, type Etat } from '@/app/tresors-actions';
import type { Lot, Partenaire } from '@/lib/tresors/types';

type Props = { lots: Lot[]; partenaires: Partenaire[]; compte: Record<string, { attribues: number; reveles: number }> };

function FormLot({ lot, partenaires, onFin }: { lot: Lot | null; partenaires: Partenaire[]; onFin?: () => void }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(async (p, fd) => { const r = await enregistrerLot(p, fd); if (r?.ok) onFin?.(); return r; }, null);
  return (
    <form action={action} style={{ border: '2px solid var(--noir)', padding: '1rem', marginBottom: '1rem', background: '#faf7f2' }}>
      <input type="hidden" name="id" value={lot?.id ?? ''} />
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="row3">
        <div className="field"><label>Nom</label><input name="nom" defaultValue={lot?.nom ?? ''} required /></div>
        <div className="field"><label>Valeur affichée</label><input name="valeur" defaultValue={lot?.valeur ?? ''} placeholder="24 €" /></div>
        <div className="field"><label>Partenaire</label>
          <select name="partenaire_id" defaultValue={lot?.partenaire_id ?? ''}><option value="">—</option>{partenaires.map((p) => <option key={p.id} value={p.id}>{p.nom}</option>)}</select></div>
      </div>
      <div className="row3">
        <div className="field"><label>Stock</label><input name="stock" type="number" min={0} defaultValue={lot?.stock ?? 1} /></div>
        <div className="field"><label>Position</label><input name="position" type="number" defaultValue={lot?.position ?? 0} /></div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center', marginTop: '1.4rem' }}>
          <input type="checkbox" name="grand" defaultChecked={lot?.grand ?? false} style={{ width: 'auto' }} /> Grand trésor (une seule carte par compte)
        </label>
      </div>
      <div style={{ display: 'flex', gap: '.5rem' }}>
        <button className="btn btn-k btn-sm" disabled={pending}>{lot ? 'Enregistrer' : '+ Ajouter le lot'}</button>
        {onFin && <button type="button" className="btn btn-w btn-sm" onClick={onFin}>Annuler</button>}
      </div>
    </form>
  );
}

function FormPartenaire({ p, onFin }: { p: Partenaire | null; onFin?: () => void }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(async (prev, fd) => { const r = await enregistrerPartenaire(prev, fd); if (r?.ok) onFin?.(); return r; }, null);
  return (
    <form action={action} style={{ border: '2px solid var(--noir)', padding: '1rem', marginBottom: '1rem', background: '#faf7f2' }}>
      <input type="hidden" name="id" value={p?.id ?? ''} />
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <div className="row2">
        <div className="field"><label>Nom</label><input name="nom" defaultValue={p?.nom ?? ''} required /></div>
        <div className="field"><label>Type</label><input name="type" defaultValue={p?.type ?? ''} placeholder="Commerce, Restaurant…" /></div>
      </div>
      <div style={{ display: 'flex', gap: '.5rem' }}>
        <button className="btn btn-k btn-sm" disabled={pending}>{p ? 'Enregistrer' : '+ Ajouter le partenaire'}</button>
        {onFin && <button type="button" className="btn btn-w btn-sm" onClick={onFin}>Annuler</button>}
      </div>
    </form>
  );
}

export default function GestionLots({ lots, partenaires, compte }: Props) {
  const [editLot, setEditLot] = useState<string | null>(null);
  const [editPart, setEditPart] = useState<string | null>(null);
  const [, start] = useTransition();

  return (
    <>
      <div className="panel">
        <h2>Lots</h2>
        <table className="tbl">
          <thead><tr><th>Nom</th><th>Valeur</th><th>Partenaire</th><th>Stock</th><th>Attribué</th><th>Révélé</th><th></th></tr></thead>
          <tbody>
            {lots.map((l) => (
              <tr key={l.id}>
                <td colSpan={editLot === l.id ? 7 : 1}>
                  {editLot === l.id ? <FormLot lot={l} partenaires={partenaires} onFin={() => setEditLot(null)} /> : <>{l.grand && <span className="pill new" style={{ marginRight: '.5rem' }}>Grand</span>}<b>{l.nom}</b></>}
                </td>
                {editLot !== l.id && (<>
                  <td>{l.valeur}</td><td>{l.tdn_partenaires?.nom ?? '—'}</td><td>{l.stock}</td>
                  <td>{compte[l.id]?.attribues ?? 0}</td><td>{compte[l.id]?.reveles ?? 0}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    <button className="btn btn-y btn-sm" onClick={() => setEditLot(l.id)}>Modifier</button>{' '}
                    <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer « ${l.nom} » ?`)) start(() => supprimerLot(l.id)); }}>✕</button>
                  </td>
                </>)}
              </tr>
            ))}
          </tbody>
        </table>
        <h3 style={{ margin: '1.4rem 0 .6rem', fontSize: '1rem' }}>Ajouter un lot</h3>
        <FormLot lot={null} partenaires={partenaires} />
      </div>

      <div className="panel">
        <h2>Partenaires</h2>
        <table className="tbl">
          <thead><tr><th>Nom</th><th>Type</th><th>Lots</th><th></th></tr></thead>
          <tbody>
            {partenaires.map((p) => (
              <tr key={p.id}>
                {editPart === p.id ? <td colSpan={4}><FormPartenaire p={p} onFin={() => setEditPart(null)} /></td> : (<>
                  <td><b>{p.nom}</b></td><td>{p.type}</td><td>{lots.filter((l) => l.partenaire_id === p.id).length}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>
                    <button className="btn btn-y btn-sm" onClick={() => setEditPart(p.id)}>Modifier</button>{' '}
                    <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer « ${p.nom} » ?`)) start(() => supprimerPartenaire(p.id)); }}>✕</button>
                  </td>
                </>)}
              </tr>
            ))}
          </tbody>
        </table>
        <h3 style={{ margin: '1.4rem 0 .6rem', fontSize: '1rem' }}>Ajouter un partenaire</h3>
        <FormPartenaire p={null} />
      </div>
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/GestionLots.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/GrandTresor.tsx' <<'EOF_PN_FICHIER'
import Hotte from './Hotte';
import { enLettres, montantGrandTresor, nombreGrandTresor, type Reglages } from '@/lib/tresors/types';

/** Visuel de la carte cadeau mise en jeu, dessinée dans la hotte. Mettre '' pour revenir aux paquets cadeaux. */
const VISUEL_CARTE = '/tresors/carte-cadeau.webp';

/**
 * Bloc « Le grand trésor » : hotte, description, montant (« 3 × 100 € ») et principe du tirage
 * (les cartes sont mêlées aux autres lots à la révélation, une seule carte par compte).
 * Commun aux deux pages d'accueil du jeu : réservation (avant l'ouverture) et jeu ouvert.
 */
export default function GrandTresor({ reglages: r }: { reglages: Reglages }) {
  // Une ou plusieurs cartes identiques, tirées au sort à la révélation avec les autres lots.
  const nombre = nombreGrandTresor(r);
  const montant = montantGrandTresor(r);
  return (
    <section className="tdn-section tdn-tresor" id="tresor">
      <Hotte className="tdn-hotte" etiquette={montant} cartes={nombre} visuelCarte={VISUEL_CARTE} />
      <h2 className="tdn-h2">Le grand trésor</h2>
      <p className="tdn-quoi">{r.grand_tresor_texte}</p>
      <div className={`tdn-montant${nombre > 1 ? ' tdn-montant-multi' : ''}`}>{montant}</div>
      {nombre > 1 ? (
        <p className="tdn-comment">Les {enLettres(nombre)} cartes sont glissées parmi les lots de la révélation. Chaque clé ouvre un trésor tiré au sort : ce sera peut-être l&apos;une d&apos;elles. Une seule carte par compte.</p>
      ) : (
        <p className="tdn-comment">Il est glissé parmi les lots de la révélation. Chaque clé ouvre un trésor tiré au sort : ce sera peut-être celui-là.</p>
      )}
      <p className="tdn-autres">…et de nombreux autres lots, un pour chaque participant qui termine l&apos;aventure.</p>
    </section>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/GrandTresor.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/Hotte.tsx' <<'EOF_PN_FICHIER'
/** Cartes cadeaux qui sortent de la hotte : centre (cx, cy) et inclinaison, de l'arrière vers l'avant. */
const POSES_CARTES: Record<number, { cx: number; cy: number; angle: number }[]> = {
  1: [{ cx: 200, cy: 86, angle: -6 }],
  2: [{ cx: 160, cy: 96, angle: -13 }, { cx: 244, cy: 90, angle: 9 }],
  3: [{ cx: 140, cy: 104, angle: -17 }, { cx: 196, cy: 78, angle: -5 }, { cx: 256, cy: 96, angle: 10 }],
};
const CARTE_L = 124;
const CARTE_H = 76.5; // proportions du visuel (480 × 296)

type Props = {
  className?: string;
  etiquette?: string;
  /** Nombre de cartes cadeaux à faire sortir de la hotte (3 au plus sont dessinées). 0 : les paquets d'origine. */
  cartes?: number;
  /** Image de la carte (fichier de /public, coins arrondis en transparence). Sans image, aucune carte n'est dessinée. */
  visuelCarte?: string;
};

/** Hotte du Père Noël débordant de cadeaux (ou des cartes du grand trésor), avec son halo intégré (rien ne déborde du SVG). */
export default function Hotte({ className = '', etiquette = '', cartes = 0, visuelCarte = '' }: Props) {
  const poses = visuelCarte ? POSES_CARTES[Math.min(Math.max(Math.floor(cartes), 0), 3)] ?? [] : [];
  // Étiquette courte (« 300 € ») ou large (« 3 × 100 € ») : le rectangle s'élargit vers la gauche du sac.
  const large = etiquette.length > 6;
  const x = large ? 208 : 236;
  const largeur = 288 - x;
  return (
    <svg className={className} viewBox="0 0 400 320" aria-hidden="true">
      <defs>
        <radialGradient id="hotte-halo" cx="50%" cy="55%" r="50%">
          <stop offset="0%" stopColor="rgba(229,192,123,.55)" /><stop offset="45%" stopColor="rgba(229,192,123,.12)" /><stop offset="100%" stopColor="rgba(229,192,123,0)" />
        </radialGradient>
        <linearGradient id="hotte-sac" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#a63a4b" /><stop offset="1" stopColor="#6b1f2c" /></linearGradient>
        <linearGradient id="hotte-or" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#f3d99a" /><stop offset="1" stopColor="#c99a3b" /></linearGradient>
        <linearGradient id="hotte-vert" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#2f7a5c" /><stop offset="1" stopColor="#1f5c45" /></linearGradient>
        <linearGradient id="hotte-bleu" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#3b5aa3" /><stop offset="1" stopColor="#172c63" /></linearGradient>
      </defs>
      <ellipse cx="200" cy="175" rx="200" ry="150" fill="url(#hotte-halo)" />

      {/* cadeaux qui dépassent (les paquets vert et bleu s'effacent quand trois cartes occupent toute l'ouverture) */}
      {poses.length < 3 && (
        <>
          <g transform="rotate(-12 150 118)"><rect x="118" y="88" width="62" height="60" rx="5" fill="url(#hotte-vert)" /><rect x="118" y="112" width="62" height="12" fill="url(#hotte-or)" /><rect x="143" y="88" width="12" height="60" fill="url(#hotte-or)" /></g>
          <g transform="rotate(10 250 108)"><rect x="216" y="70" width="70" height="72" rx="5" fill="url(#hotte-bleu)" /><rect x="216" y="100" width="70" height="12" fill="#fbf7ef" /><rect x="245" y="70" width="12" height="72" fill="#fbf7ef" /><path d="M251 66 c-12 -14 -28 -2 -10 6 c-18 0 -8 -18 10 -6 c18 -12 28 6 10 6 c18 -8 2 -20 -10 -6z" fill="#fbf7ef" /></g>
        </>
      )}
      {poses.length === 0 ? (
        <>
          <rect x="180" y="96" width="48" height="52" rx="5" fill="url(#hotte-or)" /><rect x="180" y="118" width="48" height="10" fill="#8a2a3a" /><rect x="199" y="96" width="10" height="52" fill="#8a2a3a" />
          {/* sucre d'orge */}
          <path d="M292 122 c0 -30 24 -32 26 -12" fill="none" stroke="#fbf7ef" strokeWidth="9" strokeLinecap="round" />
          <path d="M292 122 c0 -30 24 -32 26 -12" fill="none" stroke="#c22a45" strokeWidth="9" strokeLinecap="round" strokeDasharray="7 7" />
        </>
      ) : (
        // Cartes du grand trésor : glissées dans l'ouverture, le bas caché par le col de la hotte.
        poses.map((c, i) => (
          <g key={i} transform={`rotate(${c.angle} ${c.cx} ${c.cy})`}>
            <rect x={c.cx - CARTE_L / 2 + 1.5} y={c.cy - CARTE_H / 2 + 2.5} width={CARTE_L} height={CARTE_H} rx="4.5" fill="#04091a" opacity=".45" />
            <image href={visuelCarte} x={c.cx - CARTE_L / 2} y={c.cy - CARTE_H / 2} width={CARTE_L} height={CARTE_H} preserveAspectRatio="none" />
            <rect x={c.cx - CARTE_L / 2} y={c.cy - CARTE_H / 2} width={CARTE_L} height={CARTE_H} rx="4.5" fill="none" stroke="rgba(255,255,255,.35)" strokeWidth=".8" />
          </g>
        ))
      )}

      {/* sac */}
      <path d="M112 150 C 90 200 86 250 104 292 Q 200 312 296 292 C 314 250 310 200 288 150 Q 200 170 112 150 Z" fill="url(#hotte-sac)" />
      <path d="M112 150 Q 200 170 288 150" fill="none" stroke="#4d1420" strokeWidth="3" />
      {/* col de la hotte */}
      <path d="M104 148 Q 200 128 296 148 L 300 160 Q 200 186 100 160 Z" fill="#fbf7ef" />
      <path d="M104 148 Q 200 128 296 148" fill="none" stroke="#d9cdb8" strokeWidth="2" />
      {/* cordon doré */}
      <path d="M120 180 Q 200 198 280 180" fill="none" stroke="url(#hotte-or)" strokeWidth="6" strokeLinecap="round" />
      <circle cx="120" cy="181" r="7" fill="url(#hotte-or)" /><circle cx="280" cy="181" r="7" fill="url(#hotte-or)" />
      {/* plis */}
      <path d="M150 200 Q 160 250 150 290 M250 200 Q 240 250 250 290" fill="none" stroke="#4d1420" strokeWidth="2" opacity=".6" />
      {/* étiquette */}
      <g transform={`rotate(8 ${x + largeur / 2} 232)`}>
        <rect x={x} y="216" width={largeur} height="30" rx="3" fill="#fbf7ef" /><circle cx={x + 7} cy="231" r="3" fill="#8a2a3a" />
        <text x={x + largeur / 2 + (large ? 5 : 2)} y="236" textAnchor="middle" fontFamily="Cormorant Garamond, serif" fontSize={large ? 16 : 17} fontWeight="700" fill="#8a2a3a"
          textLength={etiquette.length > 10 ? largeur - 18 : undefined} lengthAdjust="spacingAndGlyphs">{etiquette}</text>
      </g>
      {/* scintillements */}
      <g fill="#fbf7ef">
        {/* avec trois cartes, les deux étoiles du haut s'écartent pour ne pas toucher les cartes */}
        <path d={`${poses.length === 3 ? 'M48 62' : 'M70 90'} l3 8 8 3 -8 3 -3 8 -3 -8 -8 -3 8 -3z`} /><path d={`${poses.length === 3 ? 'M354 44' : 'M330 60'} l2.5 6.5 6.5 2.5 -6.5 2.5 -2.5 6.5 -2.5 -6.5 -6.5 -2.5 6.5 -2.5z`} /><path d="M320 200 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z" /></g>
    </svg>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/Hotte.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/Landing.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import Neige from './Neige';
import Village from './Village';
import GrandTresor from './GrandTresor';
import type { Reglages } from '@/lib/tresors/types';

const ETAPES = [
  { n: 1, t: 'Je crée mon compte', d: 'Un responsable, une adresse e-mail.' },
  { n: 2, t: "J'inscris les participants", d: 'Adultes et enfants. Au moins un adulte inscrit pour inscrire des enfants.' },
  { n: 3, t: 'Je règle les participations', d: 'Paiement sécurisé en ligne.' },
  { n: 4, t: 'Je résous les énigmes dans le village', d: 'Les missions, ensemble ou séparément.' },
  { n: 5, t: 'Je récupère ma clé virtuelle', d: 'Une clé unique par participant.' },
];

export default function Landing({ reglages: r, connecte }: { reglages: Reglages; connecte: boolean }) {
  const RESUME = [
    { i: '🧭', t: 'Jeu autonome', d: 'Aucun bénévole nécessaire, tout se passe sur votre téléphone.' },
    { i: '🗓', t: 'Quand vous voulez', d: r.periode_texte },
    { i: '📱', t: 'Smartphone obligatoire', d: 'Un téléphone connecté par groupe suffit.' },
    { i: '⏱', t: r.duree_texte, d: 'À votre rythme, en une ou plusieurs fois.' },
    { i: '🏘', t: 'Parcours dans le village', d: 'Des lieux de Limetz-Villez à découvrir.' },
    { i: '👤', t: 'Participation individuelle', d: 'Chaque participant a sa propre clé.' },
    { i: '🎁', t: 'Lot garanti', d: 'Pour chaque participant qui termine.' },
  ];
  const ctaPrincipal = connecte
    ? <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Reprendre mon aventure</Link>
    : r.inscriptions_ouvertes
      ? <Link href="/tresors-de-noel/inscription" className="tdn-btn tdn-btn-or">Participer à l&apos;aventure</Link>
      : <span className="tdn-btn tdn-btn-ghost" aria-disabled="true">Inscriptions fermées</span>;

  return (
    <main className="tdn-landing">
      <section className="tdn-hero">
        <div className="tdn-etoiles" aria-hidden="true" />
        <Neige flocons={30} />
        <div className="tdn-hero-inner">
          <div className="tdn-sur">Comité des Fêtes de Limetz-Villez</div>
          <h1 className="tdn-titre-fee">{r.titre}</h1>
          <p className="tdn-hero-accroche">Une aventure grandeur nature au cœur du village.</p>
          <p className="tdn-hero-texte">
            Résolvez les énigmes, explorez Limetz-Villez et retrouvez votre clé virtuelle.
            Chaque participant qui termine l&apos;aventure repart avec un trésor.
          </p>
          <div className="tdn-cta">
            {ctaPrincipal}
            <Link href="/tresors-de-noel/regles" className="tdn-btn tdn-btn-ghost">Découvrir les règles</Link>
          </div>
          <p className="tdn-mini" style={{ marginTop: '1rem' }}><a href="#tresor" className="tdn-lien">Découvrir le grand trésor ↓</a></p>
          {!connecte && <p className="tdn-mini" style={{ marginTop: '1rem' }}><Link href="/tresors-de-noel/acces" className="tdn-lien">Déjà inscrit ? Retrouver mon compte</Link></p>}
        </div>
        <Village />
      </section>

      <GrandTresor reglages={r} />

      <section className="tdn-section">
        <ul className="tdn-resume">
          {RESUME.map((x) => (
            <li key={x.t}><span className="tdn-resume-ico" aria-hidden="true">{x.i}</span><b>{x.t}</b><small>{x.d}</small></li>
          ))}
        </ul>
      </section>

      <section className="tdn-section">
        <h2 className="tdn-h2">Comment ça marche ?</h2>
        <ol className="tdn-etapes">
          {ETAPES.map((e) => (
            <li key={e.n}><span className="tdn-etape-n">{e.n}</span><div><b>{e.t}</b><small>{e.d}</small></div></li>
          ))}
          <li className="tdn-etape-speciale">
            <span className="tdn-etape-n">🎁</span>
            <div><b>Je révèle mon trésor au Marché de Noël</b><small>{r.marche_texte}. Saisissez votre clé sur l&apos;écran de la Salle aux Trésors.</small></div>
          </li>
        </ol>
        <div className="tdn-cta" style={{ marginTop: '2rem' }}>{ctaPrincipal}</div>
      </section>

      <footer className="tdn-pied">
        <span>Comité des Fêtes de Limetz-Villez</span>
        <Link href="/tresors-de-noel/reglement">Règlement</Link>
        <Link href="/">← Retour au site</Link>
      </footer>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/Landing.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/LandingReservation.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import Neige from './Neige';
import Village from './Village';
import Traineau from './Traineau';
import GrandTresor from './GrandTresor';
import { euros } from '@/lib/sumup';
import type { Reglages } from '@/lib/tresors/types';

const dateLongue = (iso: string | null) => iso ? new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', timeZone: 'Europe/Paris' }).format(new Date(iso)) : '';

/** Page d'attente avant l'ouverture du jeu : réservation payante, places limitées, grand trésor. */
export default function LandingReservation({ reglages: r, connecte, placesRestantes }: { reglages: Reglages; connecte: boolean; placesRestantes: number }) {
  const complet = placesRestantes <= 0;
  const pct = r.places_max > 0 ? Math.round((placesRestantes / r.places_max) * 100) : 0;
  const debut = dateLongue(r.jeu_debut);

  const cta = connecte
    ? <Link href="/tresors-de-noel/compte" className="tdn-btn tdn-btn-or">Voir mon compte</Link>
    : complet || !r.inscriptions_ouvertes
      ? <span className="tdn-btn tdn-btn-ghost" aria-disabled="true">{complet ? 'Complet' : 'Réservations fermées'}</span>
      : <Link href="/tresors-de-noel/inscription" className="tdn-btn tdn-btn-or">Réserver mes places</Link>;

  return (
    <main className="tdn-landing tdn-resa">
      <section className="tdn-hero">
        <div className="tdn-etoiles" aria-hidden="true" />
        <Neige flocons={40} />
        <div className="tdn-halo" aria-hidden="true" />
        <Traineau className="tdn-traineau tdn-traineau-boucle" />
        <div className="tdn-hero-inner">
          <div className="tdn-sur">Comité des Fêtes de Limetz-Villez présente</div>
          <h1 className="tdn-titre-fee">{r.titre}</h1>
          <p className="tdn-hero-accroche">Les cadeaux du Père Noël ont disparu. Le village a besoin de vous.</p>
          <p className="tdn-hero-texte">
            Une chasse aux trésors grandeur nature dans les rues de Limetz-Villez : des énigmes à résoudre en famille,
            une clé virtuelle à retrouver, et un trésor garanti pour chaque participant qui termine l&apos;aventure.
          </p>
          <div className="tdn-bientot"><b>!</b> {debut ? `Le jeu commence le ${debut}` : 'Ouverture prochaine'} · places limitées</div>
          <div className="tdn-cta">
            {cta}
            <a href="#tresor" className="tdn-btn tdn-btn-ghost">Découvrir le grand trésor</a>
          </div>
          {!connecte && <p className="tdn-mini" style={{ marginTop: '1rem' }}><Link href="/tresors-de-noel/acces" className="tdn-lien">Déjà inscrit ? Retrouver mon compte</Link></p>}
        </div>
        <Village />
      </section>

      <GrandTresor reglages={r} />

      <section className="tdn-section">
        <div className="tdn-raisons">
          <div className="tdn-raison tdn-raison-or">
            <span className="tdn-resume-ico" aria-hidden="true">⏳</span>
            <h3>Les places sont comptées</h3>
            <p>Pour que chaque famille profite du village sans embouteillage aux énigmes, le nombre de participants est limité à {r.places_max}. Une fois complet, c&apos;est complet.</p>
          </div>
          <div className="tdn-raison">
            <span className="tdn-resume-ico" aria-hidden="true">🗝</span>
            <h3>Un trésor par participant</h3>
            <p>Vous jouez ensemble, sur un seul téléphone. Mais chaque participant, adulte ou enfant, termine avec sa propre clé et son propre trésor.</p>
          </div>
          <div className="tdn-raison">
            <span className="tdn-resume-ico" aria-hidden="true">🏘</span>
            <h3>Quand vous voulez</h3>
            <p>{r.periode_texte}. {r.duree_texte} de balade dans le village, à faire en une ou plusieurs fois.</p>
          </div>
          <div className="tdn-raison">
            <span className="tdn-resume-ico" aria-hidden="true">🎄</span>
            <h3>La révélation</h3>
            <p>{r.marche_texte}. Saisissez votre clé sur le grand écran de la Salle aux Trésors et découvrez votre cadeau.</p>
          </div>
        </div>
      </section>

      <section className="tdn-section" id="reservation">
        <div className="tdn-carte tdn-carte-resa">
          <span className="tdn-sceau" aria-hidden="true">✦</span>
          <h2 className="tdn-titre-fee">Réservez vos places</h2>
          <p className="tdn-muted tdn-centre-txt">Inscription en ligne, paiement sécurisé. Votre accès au jeu est créé tout de suite{debut ? `, l'aventure s'ouvre le ${debut}` : ''}.</p>
          <div className="tdn-tarifs">
            <div><span>Adulte</span><b>{euros(r.tarif_adulte_centimes)}</b></div>
            <div><span>Enfant</span><b>{euros(r.tarif_enfant_centimes)}</b></div>
          </div>
          <p className="tdn-jauge-txt">{complet ? <b>Complet</b> : <><b>Il reste {placesRestantes} place{placesRestantes > 1 ? 's' : ''}</b> sur {r.places_max}</>}</p>
          <div className="tdn-barre" aria-hidden="true"><i style={{ width: `${pct}%` }} /></div>
          <div className="tdn-cta" style={{ marginTop: '1.4rem' }}>{cta}</div>
          <p className="tdn-muted tdn-mini tdn-centre-txt" style={{ marginTop: '1rem' }}>
            Un compte pour toute la famille, une clé et un trésor par participant. Au moins un adulte doit être inscrit pour pouvoir inscrire des enfants. Les participations financent les lots et l&apos;organisation du Comité des Fêtes.
            {' '}<Link href="/tresors-de-noel/reglement" className="tdn-lien">Règlement du jeu</Link>
          </p>
        </div>
      </section>

      <footer className="tdn-pied">
        <span>Comité des Fêtes de Limetz-Villez</span>
        <Link href="/tresors-de-noel/reglement">Règlement</Link>
        <Link href="/">← Retour au site</Link>
      </footer>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/LandingReservation.tsx"
mkdir -p 'src/lib/tresors'
cat > 'src/lib/tresors/db.ts' <<'EOF_PN_FICHIER'
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

/**
 * Réglages pour l'affichage public du grand trésor : le nombre de lots suit le stock des lots
 * marqués « grand trésor » (onglet Lots), seule source de vérité de ce qui est réellement mis en jeu.
 */
export async function lireReglagesPublics(): Promise<Reglages> {
  const db = createAdminClient();
  const [r, { data: lots }] = await Promise.all([lireReglages(), db.from('tdn_lots').select('stock').eq('grand', true)]);
  const stock = (lots ?? []).reduce((s, l) => s + (Number(l.stock) || 0), 0);
  return stock > 0 ? { ...r, grand_tresor_nombre: stock } : r;
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

/** Le jeu est-il jouable maintenant ? (interrupteur admin + fenêtre de dates) */
export function jeuOuvert(r: Reglages, maintenant = new Date()): boolean {
  if (!r.jeu_actif) return false;
  if (r.jeu_debut && maintenant < new Date(r.jeu_debut)) return false;
  if (r.jeu_fin && maintenant > new Date(r.jeu_fin)) return false;
  return true;
}

/** Places : payées + en attente récente (commande SumUp en cours, 30 min). */
export async function placesPrises(): Promise<number> {
  const db = createAdminClient();
  const [{ count: payes }, { data: cmds }] = await Promise.all([
    db.from('tdn_participants').select('id', { count: 'exact', head: true }).eq('paye', true),
    db.from('tdn_commandes').select('participant_ids').eq('statut', 'en_attente').gte('created_at', new Date(Date.now() - 30 * 60 * 1000).toISOString()),
  ]);
  const enAttente = (cmds ?? []).reduce((s, c) => s + (c.participant_ids?.length ?? 0), 0);
  return (payes ?? 0) + enAttente;
}

export const dateFr = (iso: string | null, avecHeure = false) => iso
  ? new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long', ...(avecHeure ? { timeStyle: 'short' } : {}), timeZone: 'Europe/Paris' }).format(new Date(iso))
  : '—';
EOF_PN_FICHIER
echo "  ✓ src/lib/tresors/db.ts"
mkdir -p 'src/lib/tresors'
cat > 'src/lib/tresors/types.ts' <<'EOF_PN_FICHIER'
/** Types du module « Les Trésors de Noël » — miroir des tables tdn_* */

export type Categorie = 'adulte' | 'enfant';

export type Reglages = {
  id: 1;
  titre: string;
  accroche: string;
  periode_texte: string;
  marche_texte: string;
  duree_texte: string;
  tarif_adulte_centimes: number;
  tarif_enfant_centimes: number;
  inscriptions_ouvertes: boolean;
  jeu_actif: boolean;
  places_max: number;
  jeu_debut: string | null;
  jeu_fin: string | null;
  /** Montant unitaire affiché d'un lot du grand trésor, ex. « 100 € ». */
  grand_tresor_montant: string;
  grand_tresor_texte: string;
  /** Nombre de lots du grand trésor. Pour l'affichage public, il est recalculé d'après le stock des lots marqués « grand ». */
  grand_tresor_nombre: number;
  lieu_revelation: string;
  /** Colonnes de l'ancien tirage séparé du grand trésor : plus utilisées (tirage unique à la révélation). */
  tirage_cle_id: string | null;
  tirage_cle_ids: string[] | null;
  tirage_le: string | null;
  module_actif: boolean;
};

export type Partenaire = { id: string; nom: string; type: string | null };

export type Lot = {
  id: string;
  nom: string;
  valeur: string | null;
  partenaire_id: string | null;
  stock: number;
  grand: boolean;
  position: number;
  /** Jointure éventuelle */
  tdn_partenaires?: { nom: string } | null;
};

export type Bloc =
  | { type: 'texte'; contenu: string }
  | { type: 'image'; src: string; alt: string; legende?: string }
  | { type: 'audio'; titre: string; duree: string }
  | { type: 'video'; titre: string; duree: string };

export type QuestionType = 'texte' | 'code' | 'choix';

export type Mission = {
  id: string;
  numero: number;
  titre: string;
  lieu: string | null;
  accroche: string | null;
  blocs: Bloc[];
  question_type: QuestionType;
  intitule: string;
  reponses: string[];
  options: string[];
  bonne_reponse: number | null;
  longueur: number | null;
  placeholder: string | null;
  indices: string[];
  solution_secours: string | null;
  publie: boolean;
};

/** Mission telle qu'envoyée au navigateur : sans les réponses. */
export type MissionPublique = Omit<Mission, 'reponses' | 'bonne_reponse'>;

export type Compte = {
  id: string;
  token: string;
  prenom: string;
  nom: string;
  email: string;
  telephone: string | null;
};

export type Participant = {
  id: string;
  compte_id: string;
  prenom: string;
  categorie: Categorie;
  paye: boolean;
};

export type Cle = {
  id: string;
  participant_id: string;
  numero: number;
  code: string;
  lot_id: string | null;
  revelee_le: string | null;
};

export type Commande = {
  id: string;
  compte_id: string;
  reference: string;
  checkout_id: string | null;
  montant_centimes: number;
  participant_ids: string[];
  statut: 'en_attente' | 'payee' | 'echouee' | 'expiree';
  paye_le: string | null;
};

export type Stats = {
  inscrits: number;
  ca_centimes: number;
  commences: number;
  termines: number;
  cles_generees: number;
  cles_revelees: number;
};

/** Progression d'un participant, calculée côté serveur. */
export type Progression = {
  participant: Participant;
  missionsValidees: string[];   // ids de missions
  cle: Cle | null;
};

export const numeroCle = (n: number) => String(n).padStart(3, '0');

/* ---------- Grand trésor : plusieurs lots identiques, mêlés aux autres lots à la révélation ---------- */

/** Nombre de lots du grand trésor (1 au minimum, même si la colonne n'existe pas encore en base). */
export const nombreGrandTresor = (r: { grand_tresor_nombre?: number | null }) => Math.max(1, Math.floor(Number(r.grand_tresor_nombre)) || 1);

/** Montant affiché : « 3 × 100 € » s'il y a plusieurs lots, « 100 € » sinon (espaces insécables). */
export const montantGrandTresor = (r: { grand_tresor_nombre?: number | null; grand_tresor_montant: string }) => {
  const n = nombreGrandTresor(r);
  const unitaire = (r.grand_tresor_montant ?? '').replace(/ /g, '\u00a0');
  return n > 1 ? `${n}\u00a0×\u00a0${unitaire}` : unitaire;
};

const NOMBRES = ['zéro', 'une', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix'];
/** Petit nombre en toutes lettres, accordé au féminin (« une carte », « trois clés »). */
export const enLettres = (n: number) => NOMBRES[n] ?? String(n);
EOF_PN_FICHIER
echo "  ✓ src/lib/tresors/types.ts"

git add -A && git commit -m "Trésors de Noël : les 3 cartes cadeaux dans la hotte, tirage unique à la révélation" && git push
vercel --prod
