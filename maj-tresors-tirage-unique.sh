#!/usr/bin/env bash
# Trésors de Noël : tirage unique à la révélation.
#   1. Les cartes du grand trésor sont tirées au sort avec tous les autres lots, quand la clé est saisie.
#   2. Une seule carte du grand trésor par compte.
#   3. L'écran de tirage séparé du grand trésor est supprimé.
#   4. Le bloc « Le grand trésor » s'affiche aussi sur la page d'accueil quand le jeu est ouvert.
# Aucun script SQL à exécuter. Le nombre de cartes mises en jeu est le stock du lot marqué « grand trésor ».
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
rm -rf 'src/app/tresors-de-noel/tirage' 'src/components/tresors/Tirage.tsx'
echo "  ✗ écran de tirage séparé supprimé"
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
      <Hotte className="tdn-hotte" etiquette={montant} />
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

git add -A && git commit -m "Trésors de Noël : tirage unique à la révélation, cartes du grand trésor comprises, une carte par compte" && git push
vercel --prod
