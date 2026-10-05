#!/usr/bin/env bash
# Trésors de Noël :
#   1. Inscriptions : au moins un adulte inscrit sur le compte pour pouvoir inscrire des enfants.
#   2. Grand trésor : 3 cartes cadeaux multi-enseignes de 100 €, 3 clés gagnantes différentes tirées au sort.
#   3. Correctif : numeroCle n'est plus importé depuis les actions serveur dans les tableaux admin.
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
mkdir -p 'src/app/admin/(protected)/tresors/cles'
cat > 'src/app/admin/(protected)/tresors/cles/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { annulerTirage } from '@/app/tresors-actions';
import TableCles from '@/components/tresors/TableCles';
import { clesTirees, nombreGrandTresor, numeroCle, type Lot } from '@/lib/tresors/types';

export default async function AdminCles() {
  const { supabase } = await requireAdmin('tresors');
  const [{ data: cles }, { data: lots }, { data: reg }] = await Promise.all([
    supabase.from('tdn_cles').select('*, tdn_participants(prenom, tdn_comptes(prenom, nom)), tdn_lots(nom)').order('numero'),
    supabase.from('tdn_lots').select('*').order('position'),
    supabase.from('tdn_reglages').select('*').eq('id', 1).single(),
  ]);
  const nombre = nombreGrandTresor(reg ?? {});
  // Clés gagnantes, dans l'ordre du tirage.
  const gagnantes = clesTirees(reg).map((id) => (cles ?? []).find((c) => c.id === id)).filter((c) => !!c);
  const lignes = (cles ?? []).map((c) => {
    const p = c.tdn_participants as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, code: c.code, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '',
      lot_id: c.lot_id, lot: (c.tdn_lots as { nom: string } | null)?.nom ?? '', revelee: !!c.revelee_le };
  });
  return (
    <>
      <div className="adm-h"><div><h1>Clés</h1><p>{lignes.length} clés générées · {lignes.filter((l) => l.revelee).length} révélées. Le grand trésor ({nombre} lot{nombre > 1 ? 's' : ''}) se tire au sort ci-dessous ; un lot peut aussi être attribué à la main dans le tableau.</p></div></div>
      <div className="panel" style={{ borderLeft: `10px solid ${reg?.tirage_le ? '#9BD44F' : '#FFD400'}` }}>
        <h2>Tirage du grand trésor</h2>
        {reg?.tirage_le ? (
          <p>
            Effectué le {new Date(reg.tirage_le).toLocaleString('fr-FR', { timeZone: 'Europe/Paris' })} · clé{gagnantes.length > 1 ? 's' : ''} gagnante{gagnantes.length > 1 ? 's' : ''} :{' '}
            {gagnantes.length === 0 ? <b className="mono">?</b> : gagnantes.map((g, i) => {
              const p = g!.tdn_participants as { prenom: string } | null;
              return <span key={g!.id}>{i > 0 && ', '}<b className="mono">n° {numeroCle(g!.numero)}</b>{p?.prenom && ` (${p.prenom})`}</span>;
            })}.
          </p>
        ) : (
          <p>Pas encore effectué. Toutes les clés générées participent : {nombre > 1 ? `${nombre} clés différentes sont tirées au sort, une par lot` : 'une clé est tirée au sort'}. Le résultat est enregistré et verrouillé dès le clic sur « Lancer le tirage ».</p>
        )}
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', marginTop: '1rem' }}>
          <Link className="btn btn-k btn-sm" href="/tresors-de-noel/tirage" target="_blank">↗ Ouvrir l&apos;écran du tirage</Link>
          {reg?.tirage_le && (
            <form action={async () => { 'use server'; await annulerTirage(); }}>
              <button className="btn btn-w btn-sm">Annuler le tirage</button>
            </form>
          )}
        </div>
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
  const [{ data: lots }, { data: partenaires }, { data: attribs }] = await Promise.all([
    supabase.from('tdn_lots').select('*, tdn_partenaires(nom)').order('position'),
    supabase.from('tdn_partenaires').select('*').order('nom'),
    supabase.from('tdn_cles').select('lot_id, revelee_le').not('lot_id', 'is', null),
  ]);
  const compte: Record<string, { attribues: number; reveles: number }> = {};
  for (const a of attribs ?? []) {
    const c = (compte[a.lot_id!] ??= { attribues: 0, reveles: 0 });
    c.attribues++; if (a.revelee_le) c.reveles++;
  }
  return (
    <>
      <div className="adm-h"><div><h1>Lots et partenaires</h1><p>Les lots sont attribués au moment de la révélation, dans la limite du stock. Le « grand trésor » n&apos;est pas distribué à la révélation : ses gagnants sont tirés au sort depuis l&apos;onglet Clés (nombre de lots dans les Réglages).</p></div></div>
      <GestionLots lots={(lots ?? []) as Lot[]} partenaires={(partenaires ?? []) as Partenaire[]} compte={compte} />
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
            <Link className="btn btn-w btn-sm" href="/admin/tresors/cles">Tirage du grand trésor</Link>
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
import { clesTirees, nombreGrandTresor } from '@/lib/tresors/types';

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
    grand_tresor_nombre: Math.min(50, Math.max(1, Math.round(Number(fd.get('grand_tresor_nombre') ?? 1)) || 1)),
    grand_tresor_montant: String(fd.get('grand_tresor_montant') ?? '').trim(),
    grand_tresor_texte: String(fd.get('grand_tresor_texte') ?? '').trim(),
    lieu_revelation: String(fd.get('lieu_revelation') ?? '').trim(),
  }).eq('id', 1);
  if (error) return { erreur: /grand_tresor_nombre/.test(error.message) ? 'Colonne manquante : exécutez supabase/tresors_v2.sql dans Supabase, puis réessayez.' : error.message };
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


/* =========================================================
   TIRAGE DU GRAND TRÉSOR (écran admin)
   ========================================================= */
export type Gagnant = { cleId: string; numero: number; prenom: string; famille: string };
export type ResultatTirage = { ok: true; gagnants: Gagnant[]; deja: boolean } | { ok: false; erreur: string };

const SQL_MANQUANT = 'Réglages du tirage illisibles : exécutez supabase/tresors_v2.sql dans Supabase, puis réessayez.';

/** Détail des clés gagnantes, dans l'ordre du tirage. */
async function lireGagnants(ids: string[]): Promise<Gagnant[]> {
  if (ids.length === 0) return [];
  const db = createAdminClient();
  const { data } = await db.from('tdn_cles').select('id, numero, tdn_participants(prenom, tdn_comptes(prenom, nom))').in('id', ids);
  const parId = new Map((data ?? []).map((c) => [c.id as string, c]));
  return ids.flatMap((id) => {
    const c = parId.get(id);
    if (!c) return [];
    const p = c.tdn_participants as unknown as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return [{ cleId: c.id as string, numero: c.numero as number, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '' }];
  });
}

/**
 * Tire au sort les clés gagnantes du grand trésor (autant que de lots, réglage « grand_tresor_nombre »),
 * parmi toutes les clés générées. Les clés sont toutes différentes : une clé ne gagne qu'un seul lot.
 * Le résultat est enregistré et verrouillé ; un second appel renvoie le même résultat.
 */
export async function tirerGrandTresor(): Promise<ResultatTirage> {
  await admin();
  const db = createAdminClient();
  const { data: r } = await db.from('tdn_reglages').select('*').eq('id', 1).single();
  if (!r) return { ok: false, erreur: SQL_MANQUANT };
  const dejaTirees = clesTirees(r);
  if (dejaTirees.length > 0) return { ok: true, gagnants: await lireGagnants(dejaTirees), deja: true };

  const { data: cles } = await db.from('tdn_cles').select('id');
  if (!cles || cles.length === 0) return { ok: false, erreur: 'Aucune clé générée : personne n’a terminé le jeu.' };
  const { data: grand } = await db.from('tdn_lots').select('id').eq('grand', true).order('position').limit(1).maybeSingle();
  if (!grand) return { ok: false, erreur: 'Aucun lot marqué « grand trésor » dans les lots.' };

  // Mélange de Fisher-Yates partiel avec l'aléa cryptographique du serveur : N clés distinctes.
  const ids = cles.map((c) => c.id as string);
  const nombre = Math.min(nombreGrandTresor(r), ids.length);
  for (let i = 0; i < nombre; i++) {
    const j = i + randomInt(ids.length - i);
    [ids[i], ids[j]] = [ids[j], ids[i]];
  }
  const gagnantes = ids.slice(0, nombre);

  // Verrou : on n’écrit que si aucun tirage n’a été enregistré entre-temps.
  const { data: maj, error } = await db.from('tdn_reglages')
    .update({ tirage_cle_id: gagnantes[0], tirage_cle_ids: gagnantes, tirage_le: new Date().toISOString() })
    .eq('id', 1).is('tirage_cle_id', null).select('tirage_cle_id').maybeSingle();
  if (error) { console.error('[tirerGrandTresor]', error); return { ok: false, erreur: SQL_MANQUANT }; }
  if (!maj) {
    const { data: r2 } = await db.from('tdn_reglages').select('*').eq('id', 1).single();
    return { ok: true, gagnants: await lireGagnants(clesTirees(r2)), deja: true };
  }
  await db.from('tdn_cles').update({ lot_id: grand.id }).in('id', gagnantes);
  chemins();
  return { ok: true, gagnants: await lireGagnants(gagnantes), deja: false };
}

/** Annule le tirage (retire le grand trésor des clés gagnantes) pour pouvoir le relancer. */
export async function annulerTirage() {
  await admin();
  const db = createAdminClient();
  const { data: r } = await db.from('tdn_reglages').select('*').eq('id', 1).single();
  const ids = clesTirees(r);
  if (ids.length > 0) await db.from('tdn_cles').update({ lot_id: null, revelee_le: null }).in('id', ids);
  const { error } = await db.from('tdn_reglages').update({ tirage_cle_id: null, tirage_cle_ids: [], tirage_le: null }).eq('id', 1);
  // Base pas encore migrée (colonne tirage_cle_ids absente) : on libère au moins l'ancien verrou.
  if (error) await db.from('tdn_reglages').update({ tirage_cle_id: null, tirage_le: null }).eq('id', 1);
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
  const nbGrand = nombreGrandTresor(r);
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
      <p><b>Chaque participant ayant obtenu sa clé virtuelle reçoit un lot</b>, dans les conditions de l&apos;article 7. Les lots sont attribués par tirage au sort informatique au moment de la révélation, parmi les lots disponibles, à l&apos;exception du grand trésor.</p>
      {nbGrand > 1 ? (
        <p>Le <b>grand trésor</b> est composé de <b>{nbGrandTexte} cartes cadeaux multi-enseignes d&apos;une valeur unitaire de {r.grand_tresor_montant}</b>, utilisables dans l&apos;ensemble des enseignes partenaires de l&apos;émetteur. Il est attribué par tirage au sort, effectué sous le contrôle de l&apos;Organisateur, parmi l&apos;ensemble des clés virtuelles générées avant la clôture du Jeu : {nbGrandTexte} clés différentes sont tirées au sort et chacune remporte une carte cadeau. Une même clé ne peut remporter qu&apos;une seule carte ; plusieurs clés d&apos;un même compte peuvent en revanche être tirées au sort. Les clés gagnantes sont révélées lors de la cérémonie de révélation.</p>
      ) : (
        <p>Le <b>grand trésor</b> est une carte cadeau multi-enseignes d&apos;une valeur de {r.grand_tresor_montant}, utilisable dans l&apos;ensemble des enseignes partenaires de l&apos;émetteur. Il est attribué par tirage au sort, effectué sous le contrôle de l&apos;Organisateur, parmi l&apos;ensemble des clés virtuelles générées avant la clôture du Jeu, et révélé lors de la cérémonie de révélation.</p>
      )}
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
mkdir -p 'src/app/tresors-de-noel/regles'
cat > 'src/app/tresors-de-noel/regles/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import Entete from '@/components/tresors/Entete';
import NavTresors from '@/components/tresors/NavTresors';
import { lireMissions, lireReglages } from '@/lib/tresors/db';
import { euros } from '@/lib/sumup';

export default async function PageRegles() {
  const [r, missions] = await Promise.all([lireReglages(), lireMissions()]);
  const n = missions.length;
  const REGLES = [
    { t: 'Le principe', d: `${n} missions vous attendent dans le village. À chaque lieu, une énigme à résoudre sur votre téléphone. Une bonne réponse débloque la mission suivante.` },
    { t: 'Quand jouer ?', d: `${r.periode_texte}, à toute heure. Le parcours est prévu pour ${r.duree_texte.toLowerCase()}, mais vous pouvez le faire en plusieurs fois : votre progression est sauvegardée.` },
    { t: 'En famille ou entre amis', d: "Chaque participant est inscrit individuellement, mais vous jouez ensemble sur un seul téléphone. Le responsable valide une mission pour tous les participants présents d'un coup. Au moins un adulte doit être inscrit sur le compte pour pouvoir inscrire des enfants." },
    { t: 'La clé virtuelle', d: `Quand un participant termine les ${n} missions, une clé unique est créée dans son compte : un numéro et un code secret. Gardez-la précieusement.` },
    { t: 'Le Marché de Noël', d: `${r.marche_texte}. Rendez-vous à la Salle aux Trésors : saisissez votre clé sur le grand écran et découvrez votre lot. Chaque participant ayant terminé repart avec un trésor.` },
    { t: 'Les indices', d: "Bloqué ? Chaque mission propose des indices, puis une solution de secours. Aucune pénalité : l'important est de terminer." },
    { t: 'Tarifs', d: `${euros(r.tarif_adulte_centimes)} par adulte, ${euros(r.tarif_enfant_centimes)} par enfant. Le montant sert à financer les lots et les animations du Comité des Fêtes.` },
    { t: 'Respect des lieux', d: "Les énigmes se résolvent par l'observation. Rien à déplacer, rien à ouvrir, rien à emporter. Restez sur la voie publique et respectez les riverains." },
  ];
  return (
    <main className="tdn-page">
      <Entete titre="Les règles du jeu" sur="Tout savoir avant de partir" />
      <div className="tdn-regles">
        {REGLES.map((x, i) => (
          <article key={x.t} className="tdn-carte"><div className="tdn-sur">Règle {i + 1}</div><h2>{x.t}</h2><p>{x.d}</p></article>
        ))}
      </div>
      {r.inscriptions_ouvertes && (
        <div className="tdn-cta"><Link href="/tresors-de-noel/inscription" className="tdn-btn tdn-btn-or">Participer à l&apos;aventure</Link></div>
      )}
      <NavTresors />
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-de-noel/regles/page.tsx"
mkdir -p 'src/app/tresors-de-noel/tirage'
cat > 'src/app/tresors-de-noel/tirage/page.tsx' <<'EOF_PN_FICHIER'
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import Tirage from '@/components/tresors/Tirage';
import { lireReglages } from '@/lib/tresors/db';
import { clesTirees, nombreGrandTresor } from '@/lib/tresors/types';

/** Écran grand format du tirage du grand trésor (une clé gagnante par lot). Réservé aux administrateurs connectés. */
export default async function PageTirage() {
  const { user, isAdmin } = await requireAdmin('tresors');
  if (!user || !isAdmin) redirect('/admin/login');
  const db = createAdminClient();
  const [r, { data: cles }, { data: grand }] = await Promise.all([
    lireReglages(),
    db.from('tdn_cles').select('id, numero, tdn_participants(prenom, tdn_comptes(prenom, nom))').order('numero'),
    db.from('tdn_lots').select('nom').eq('grand', true).order('position').limit(1).maybeSingle(),
  ]);
  const liste = (cles ?? []).map((c) => {
    const p = c.tdn_participants as unknown as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '' };
  });
  const lot = `${r.grand_tresor_texte} de ${r.grand_tresor_montant}`;
  return <Tirage cles={liste} nombre={nombreGrandTresor(r)} lot={lot} lotUnitaire={grand?.nom ?? lot} tirageFait={clesTirees(r).length > 0} />;
}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-de-noel/tirage/page.tsx"
mkdir -p 'src/app/tresors-de-noel'
cat > 'src/app/tresors-de-noel/tresors.css' <<'EOF_PN_FICHIER'
/* =========================================================
   LES TRÉSORS DE NOËL — feuille dédiée, préfixe .tdn
   Palette : bleu nuit, blanc neige, doré chaud, bordeaux, sapin.
   Mobile-first ; les styles globaux du site ne sont pas modifiés.
   ========================================================= */
@import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,500;0,600;0,700;1,500&display=swap');

.tdn{
  --tdn-nuit:#081430; --tdn-nuit-2:#0f2150; --tdn-nuit-3:#172c63;
  --tdn-creme:#fbf7ef; --tdn-neige:#ffffff; --tdn-or:#e5c07b; --tdn-or-2:#c99a3b;
  --tdn-bordeaux:#8a2a3a; --tdn-sapin:#1f5c45; --tdn-texte:#e9e4d8; --tdn-muted:#a9b3cc;
  --tdn-ombre:0 12px 40px rgba(0,0,0,.35);
  --tdn-radius:18px;
  min-height:100vh; background:var(--tdn-nuit); color:var(--tdn-texte);
  font-family:'Bricolage Grotesque',system-ui,sans-serif; -webkit-font-smoothing:antialiased;
  overflow-x:hidden;
}
.tdn *{box-sizing:border-box;}
.tdn :where(h1,h2,h3){text-transform:none;letter-spacing:0;font-family:'Bricolage Grotesque',system-ui,sans-serif;font-weight:700;}
.tdn :where(section){padding:0;}
.tdn :where(footer){background:transparent;padding:0;display:block;color:inherit;}
.tdn a{color:inherit;}
.tdn button{font-family:inherit;}
.tdn-titre-fee{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;line-height:1.05;letter-spacing:.005em;}
.tdn-sur{font-family:'DM Mono',ui-monospace,monospace;text-transform:uppercase;letter-spacing:.16em;
  font-size:.66rem;color:var(--tdn-or);}
.tdn-sur-grand{font-size:.85rem;}
.tdn-muted{color:var(--tdn-muted);}
.tdn-mini{font-size:.8rem;}
.tdn-sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);}
.tdn-fond-nuit{background:var(--tdn-nuit);}
.tdn-p{max-width:40ch;margin:0 auto 1.4rem;line-height:1.55;}
.tdn-centre{text-align:center;display:flex;flex-direction:column;align-items:center;}

/* ---------- Décor : étoiles, neige, village, halo ---------- */
.tdn-etoiles{position:absolute;inset:0;pointer-events:none;opacity:.8;
  background-image:
    radial-gradient(1px 1px at 12% 18%,#fff 60%,transparent 61%),
    radial-gradient(1.5px 1.5px at 78% 12%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 40% 32%,#fff 60%,transparent 61%),
    radial-gradient(1.2px 1.2px at 88% 40%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 25% 55%,#fff 60%,transparent 61%),
    radial-gradient(1.5px 1.5px at 60% 22%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 5% 70%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 50% 8%,#fff 60%,transparent 61%),
    radial-gradient(1.2px 1.2px at 95% 66%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 70% 48%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 33% 78%,#fff 60%,transparent 61%);
  animation:tdn-etoile 5s ease-in-out infinite alternate;}
@keyframes tdn-etoile{from{opacity:.55}to{opacity:.95}}
.tdn-neige{position:absolute;inset:0;overflow:hidden;pointer-events:none;}
.tdn-neige i{position:absolute;top:-10px;border-radius:50%;background:#fff;
  animation:tdn-chute linear infinite;}
@keyframes tdn-chute{to{transform:translateY(110vh) translateX(18px);}}
.tdn-village{position:absolute;left:0;right:0;bottom:0;width:100%;height:auto;display:block;pointer-events:none;}
.tdn-fenetre{animation:tdn-fenetre 3s ease-in-out infinite alternate;}
@keyframes tdn-fenetre{from{opacity:.55}to{opacity:1}}
.tdn-halo{position:absolute;left:50%;top:38%;width:70vmin;height:70vmin;transform:translate(-50%,-50%);
  border-radius:50%;pointer-events:none;
  background:radial-gradient(circle,rgba(229,192,123,.28) 0%,rgba(229,192,123,.08) 40%,transparent 70%);
  animation:tdn-halo 4s ease-in-out infinite alternate;}
@keyframes tdn-halo{from{transform:translate(-50%,-50%) scale(.9)}to{transform:translate(-50%,-50%) scale(1.08)}}

/* ---------- Intro ---------- */
.tdn-intro{position:fixed;inset:0;z-index:50;background:radial-gradient(ellipse at 50% 20%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);
  display:flex;align-items:center;justify-content:center;overflow:hidden;
  transition:opacity .7s ease;}
.tdn-intro.sortie{opacity:0;pointer-events:none;}
.tdn-traineau{position:absolute;top:14%;left:-340px;width:clamp(200px,45vw,320px);height:auto;color:rgba(251,247,239,.7);
  filter:drop-shadow(0 0 14px rgba(229,192,123,.45));animation:tdn-traineau 10s ease-in-out 1.2s forwards;}
@keyframes tdn-traineau{0%{left:-340px;top:18%;opacity:0}8%{opacity:1}92%{opacity:1}100%{left:110%;top:6%;opacity:0}}
.tdn-intro-texte{position:relative;z-index:2;padding:0 1.6rem;text-align:center;max-width:36rem;}
.tdn-intro-phrase{font-family:'Cormorant Garamond',Georgia,serif;font-size:clamp(1.6rem,6vw,2.6rem);
  font-weight:500;font-style:italic;line-height:1.25;color:var(--tdn-creme);
  animation:tdn-fondu 2.3s ease-in-out both;}
@keyframes tdn-fondu{0%{opacity:0;transform:translateY(10px)}20%{opacity:1;transform:none}80%{opacity:1}100%{opacity:0;transform:translateY(-8px)}}
.tdn-intro-titre{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;
  font-size:clamp(2.1rem,8.5vw,4rem);line-height:1.05;color:var(--tdn-or);
  text-shadow:0 0 30px rgba(229,192,123,.45);animation:tdn-apparait 1.6s ease-out both;}
@keyframes tdn-apparait{from{opacity:0;transform:scale(.94);filter:blur(6px)}to{opacity:1;transform:none;filter:none}}
.tdn-scintille{display:inline-block;margin:0 .4em;font-size:.55em;vertical-align:middle;color:var(--tdn-creme);
  animation:tdn-scintille 1.4s ease-in-out infinite;}
.tdn-scintille-2{animation-delay:.7s;}
@keyframes tdn-scintille{0%,100%{opacity:.3;transform:scale(.7)}50%{opacity:1;transform:scale(1.15)}}
.tdn-passer{position:absolute;right:1rem;bottom:calc(1rem + env(safe-area-inset-bottom));z-index:3;
  background:rgba(8,20,48,.5);color:var(--tdn-muted);border:1px solid rgba(255,255,255,.18);
  padding:.7rem 1.1rem;border-radius:999px;font-size:.8rem;cursor:pointer;backdrop-filter:blur(6px);}
.tdn-passer:hover{color:var(--tdn-creme);border-color:var(--tdn-or);}

/* ---------- Landing ---------- */
.tdn-landing{padding-bottom:5.5rem;}
.tdn-hero{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;
  padding:5rem 1.4rem 9rem;overflow:hidden;text-align:center;
  background:radial-gradient(ellipse at 50% 15%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);}
.tdn-hero-inner{position:relative;z-index:2;max-width:38rem;}
.tdn-hero h1{font-size:clamp(2.4rem,10vw,4.6rem);color:var(--tdn-or);margin:.8rem 0 1rem;
  text-shadow:0 0 40px rgba(229,192,123,.35);}
.tdn-hero-accroche{font-family:'Cormorant Garamond',Georgia,serif;font-style:italic;font-size:1.35rem;color:var(--tdn-creme);}
.tdn-hero-texte{margin:1rem auto 1.8rem;max-width:34ch;line-height:1.55;color:var(--tdn-texte);}
.tdn-cta{display:flex;flex-direction:column;gap:1rem;align-items:stretch;margin-top:1.4rem;}
@media(min-width:560px){.tdn-cta{flex-direction:row;justify-content:center;}}

.tdn-section{padding:2.5rem 1.2rem;max-width:44rem;margin:0 auto;}
.tdn-h2{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:2.1rem;color:var(--tdn-or);
  text-align:center;margin-bottom:1.5rem;}
.tdn-tresor .tdn-h2{margin-bottom:.2rem;}
.tdn-resume{list-style:none;padding:0;margin:0;display:grid;grid-template-columns:1fr 1fr;gap:.7rem;}
@media(min-width:640px){.tdn-resume{grid-template-columns:repeat(3,1fr);}}
.tdn-resume li{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:var(--tdn-radius);
  padding:1rem .9rem;display:flex;flex-direction:column;gap:.25rem;}
.tdn-resume-ico{font-size:1.4rem;}
.tdn-resume b{font-size:.95rem;color:var(--tdn-creme);}
.tdn-resume small{color:var(--tdn-muted);font-size:.78rem;line-height:1.35;}
.tdn-etapes{list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:.6rem;}
.tdn-etapes li{display:flex;gap:.9rem;align-items:flex-start;background:rgba(255,255,255,.05);
  border:1px solid rgba(255,255,255,.1);border-radius:var(--tdn-radius);padding:1rem;}
.tdn-etapes b{display:block;color:var(--tdn-creme);}
.tdn-etapes small{color:var(--tdn-muted);line-height:1.4;}
.tdn-etape-n{flex:0 0 2.2rem;height:2.2rem;border-radius:50%;display:grid;place-items:center;
  background:var(--tdn-nuit-3);color:var(--tdn-or);font-weight:700;border:1px solid rgba(229,192,123,.4);}
.tdn-etape-speciale{background:linear-gradient(135deg,rgba(229,192,123,.22),rgba(138,42,58,.25))!important;
  border-color:rgba(229,192,123,.5)!important;}
.tdn-pied{display:flex;justify-content:space-between;gap:1rem;flex-wrap:wrap;padding:2rem 1.4rem;
  color:var(--tdn-muted);font-size:.8rem;border-top:1px solid rgba(255,255,255,.08);}

/* ---------- Boutons ---------- */
.tdn-btn{display:inline-flex;align-items:center;justify-content:center;gap:.5rem;min-height:3.25rem;
  padding:.9rem 1.5rem;border-radius:999px;font-weight:700;font-size:1rem;text-decoration:none;
  border:2px solid transparent;cursor:pointer;transition:transform .12s,box-shadow .12s,background .15s;
  -webkit-tap-highlight-color:transparent;}
.tdn-btn:active{transform:scale(.98);}
.tdn-btn:disabled{opacity:.45;cursor:not-allowed;}
.tdn-btn-or{background:linear-gradient(135deg,var(--tdn-or),var(--tdn-or-2));color:var(--tdn-nuit);
  box-shadow:0 8px 24px rgba(229,192,123,.3);}
.tdn-btn-or:hover:not(:disabled){box-shadow:0 10px 30px rgba(229,192,123,.45);}
.tdn-btn-ghost{background:transparent;color:var(--tdn-creme);border-color:rgba(255,255,255,.3);}
.tdn-btn-ghost:hover:not(:disabled){border-color:var(--tdn-or);color:var(--tdn-or);}
.tdn-btn-nuit{background:var(--tdn-nuit);color:var(--tdn-or);}
.tdn-btn-large{width:100%;margin-top:1rem;}
.tdn-btn-xl{width:100%;min-height:4rem;font-size:1.3rem;text-transform:uppercase;letter-spacing:.06em;}
.tdn-lien{background:none;border:none;color:var(--tdn-muted);text-decoration:underline;cursor:pointer;
  font-size:.9rem;padding:.6rem 0;font-family:inherit;}
.tdn-lien:hover{color:var(--tdn-or);}
.tdn-mini-lien{margin-left:auto;font-size:.8rem;color:var(--tdn-or);text-decoration:none;align-self:center;padding:.4rem;}
.tdn-actions{display:flex;gap:.7rem;margin-top:1rem;}
.tdn-actions .tdn-btn{flex:1;}
.tdn-actions-col{flex-direction:column;}

/* ---------- Pages internes ---------- */
.tdn-page{max-width:36rem;margin:0 auto;padding:1rem 1rem 6.5rem;min-height:100svh;}
.tdn-entete{display:flex;align-items:center;gap:.8rem;padding:.6rem 0 1.2rem;}
.tdn-entete h1{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:1.9rem;line-height:1.05;color:var(--tdn-creme);}
.tdn-retour{flex:0 0 2.8rem;height:2.8rem;border-radius:50%;display:grid;place-items:center;
  background:rgba(255,255,255,.08);text-decoration:none;font-size:1.2rem;color:var(--tdn-creme);}
.tdn-carte{background:rgba(255,255,255,.055);border:1px solid rgba(255,255,255,.1);border-radius:var(--tdn-radius);
  padding:1.3rem 1.2rem;margin-bottom:1rem;}
.tdn-carte h2{font-size:1.2rem;color:var(--tdn-creme);margin-bottom:.6rem;}
.tdn-carte p{line-height:1.55;}
.tdn-carte .tdn-titre-fee{font-size:1.9rem;color:var(--tdn-or);margin:.3rem 0 .5rem;}
.tdn-or{background:linear-gradient(135deg,rgba(229,192,123,.22),rgba(201,154,59,.12));border-color:rgba(229,192,123,.5);}
.tdn-regles article p{color:var(--tdn-texte);margin-top:.3rem;}
.tdn-lieu{color:var(--tdn-or);font-weight:600;margin-bottom:.6rem;}
.tdn-liste-num{padding-left:1.3rem;line-height:1.7;}

/* Formulaires */
.tdn-champ{margin-bottom:.9rem;}
.tdn-champ label{display:block;font-family:'DM Mono',monospace;font-size:.66rem;letter-spacing:.14em;
  text-transform:uppercase;color:var(--tdn-muted);margin-bottom:.4rem;}
.tdn-champ input{width:100%;min-height:3.25rem;padding:.8rem 1rem;border-radius:12px;font-size:1.05rem;
  background:rgba(8,20,48,.6);border:2px solid rgba(255,255,255,.18);color:var(--tdn-creme);font-family:inherit;}
.tdn-champ input::placeholder{color:rgba(169,179,204,.6);}
.tdn-champ input:focus{outline:none;border-color:var(--tdn-or);box-shadow:0 0 0 4px rgba(229,192,123,.2);}
.tdn-champ-grand input{font-size:1.8rem;text-align:center;min-height:4.2rem;font-family:'DM Mono',monospace;letter-spacing:.1em;}
.tdn-champ-grand label{font-size:.9rem;text-align:center;}
.tdn-code-input{font-family:'DM Mono',monospace;font-size:1.8rem!important;text-align:center;letter-spacing:.35em;}
.tdn-stepper{display:flex;gap:.4rem;margin-bottom:1.2rem;}
.tdn-stepper span{flex:1;height:5px;border-radius:5px;background:rgba(255,255,255,.12);}
.tdn-stepper span.on{background:var(--tdn-or);}
.tdn-ligne-part{display:flex;gap:.6rem;align-items:flex-end;}
.tdn-toggle{display:flex;border:2px solid rgba(255,255,255,.18);border-radius:12px;overflow:hidden;margin-bottom:.9rem;}
.tdn-toggle button{background:transparent;border:none;color:var(--tdn-muted);padding:0 .9rem;min-height:3.25rem;cursor:pointer;font-weight:600;}
.tdn-toggle button.on{background:var(--tdn-or);color:var(--tdn-nuit);}
.tdn-toggle button:disabled{opacity:.35;cursor:not-allowed;}
.tdn-suppr{flex:0 0 2.6rem;height:3.25rem;margin-bottom:.9rem;background:transparent;border:2px solid rgba(255,255,255,.18);
  border-radius:12px;color:var(--tdn-muted);cursor:pointer;font-size:1rem;}
.tdn-suppr:hover{border-color:var(--tdn-bordeaux);color:#f0a0ae;}
.tdn-suppr:disabled{opacity:.3;cursor:not-allowed;border-color:rgba(255,255,255,.18);color:var(--tdn-muted);}
/* Règle « au moins un adulte pour inscrire des enfants » */
.tdn-regle-adulte{margin:.2rem 0 1rem;padding:.6rem .8rem;border-left:3px solid var(--tdn-or);border-radius:0 10px 10px 0;background:rgba(229,192,123,.1);font-size:.88rem;color:var(--tdn-texte);}
.tdn-regle-adulte b{color:var(--tdn-or);}
.tdn-recap{list-style:none;padding:0;margin:1rem 0;}
.tdn-recap li{display:flex;justify-content:space-between;padding:.7rem 0;border-bottom:1px solid rgba(255,255,255,.1);}
.tdn-recap small{color:var(--tdn-muted);}
.tdn-recap-total{font-size:1.2rem;color:var(--tdn-or);border-bottom:none!important;}
.tdn-succes{width:4.5rem;height:4.5rem;border-radius:50%;display:grid;place-items:center;margin:3rem auto 1.5rem;
  background:var(--tdn-sapin);color:#fff;font-size:2rem;font-weight:700;box-shadow:0 0 40px rgba(31,92,69,.6);}
.tdn-centre .tdn-titre-fee{font-size:2.2rem;color:var(--tdn-or);margin-bottom:1rem;}

/* Compte / participants */
.tdn-participants{list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:.6rem;}
.tdn-participants li{display:flex;gap:.5rem;align-items:center;}
.tdn-part-sel{flex:1;display:flex;gap:.9rem;align-items:center;text-align:left;background:rgba(8,20,48,.5);
  border:2px solid rgba(255,255,255,.12);border-radius:14px;padding:.8rem;cursor:pointer;color:inherit;}
.tdn-participants li.on .tdn-part-sel{border-color:var(--tdn-or);}
.tdn-avatar{flex:0 0 2.6rem;height:2.6rem;border-radius:50%;display:grid;place-items:center;font-weight:700;
  background:var(--tdn-nuit-3);color:var(--tdn-or);font-family:'Cormorant Garamond',serif;font-size:1.4rem;}
.tdn-part-info{flex:1;display:flex;flex-direction:column;gap:.2rem;}
.tdn-part-info b{color:var(--tdn-creme);}
.tdn-part-info small{color:var(--tdn-muted);font-size:.78rem;}
.tdn-participants .tdn-suppr{margin-bottom:0;height:2.6rem;}
.tdn-pastille{font-family:'DM Mono',monospace;font-size:.62rem;letter-spacing:.12em;text-transform:uppercase;
  padding:.3rem .6rem;border-radius:999px;background:rgba(229,192,123,.18);color:var(--tdn-or);white-space:nowrap;}
.tdn-pastille-ok{background:rgba(31,92,69,.35);color:#9fe0c0;}

/* Progression */
.tdn-compteur{font-size:1.1rem;margin:.3rem 0 .6rem;color:var(--tdn-creme);}
.tdn-compteur b{font-family:'Cormorant Garamond',serif;font-size:2.6rem;color:var(--tdn-or);line-height:1;}
.tdn-barre{height:12px;border-radius:12px;background:rgba(255,255,255,.1);overflow:hidden;}
.tdn-barre i{display:block;height:100%;border-radius:12px;background:linear-gradient(90deg,var(--tdn-or-2),var(--tdn-or));
  transition:width .6s ease;box-shadow:0 0 12px rgba(229,192,123,.6);}
.tdn-barre-mini{height:6px;margin:.2rem 0;}
.tdn-switch{margin-top:1.1rem;}
.tdn-chips{display:flex;gap:.5rem;flex-wrap:wrap;margin-top:.5rem;}
.tdn-chips button{min-height:2.8rem;padding:0 1.1rem;border-radius:999px;cursor:pointer;font-weight:600;
  background:rgba(255,255,255,.07);border:2px solid rgba(255,255,255,.15);color:var(--tdn-texte);}
.tdn-chips button.on{background:var(--tdn-or);border-color:var(--tdn-or);color:var(--tdn-nuit);}
.tdn-mission-carte{padding:1.6rem 1.3rem;}
.tdn-parcours{list-style:none;padding:0;margin:0;}
.tdn-parcours li{display:flex;gap:.8rem;align-items:center;padding:.55rem 0;border-bottom:1px solid rgba(255,255,255,.07);color:var(--tdn-muted);}
.tdn-parcours li:last-child{border-bottom:none;}
.tdn-parcours b{display:block;font-size:.95rem;}
.tdn-parcours small{font-size:.75rem;}
.tdn-parcours li.ok .tdn-etape-n{background:var(--tdn-sapin);color:#fff;border-color:transparent;}
.tdn-parcours li.ok b{color:var(--tdn-creme);}
.tdn-parcours li.now{color:var(--tdn-creme);}
.tdn-parcours li.now .tdn-etape-n{background:var(--tdn-or);color:var(--tdn-nuit);}

/* Mission */
.tdn-recit{font-family:'Cormorant Garamond',Georgia,serif;font-size:1.25rem;line-height:1.45;color:var(--tdn-creme);margin-bottom:1rem;}
.tdn-media{margin:0 0 1rem;}
.tdn-media-img{border-radius:14px;overflow:hidden;border:1px solid rgba(255,255,255,.12);}
.tdn-media-img svg{display:block;width:100%;height:auto;}
.tdn-media-video{aspect-ratio:16/9;display:grid;place-items:center;background:linear-gradient(135deg,var(--tdn-nuit-3),var(--tdn-nuit));}
.tdn-media figcaption{font-size:.8rem;color:var(--tdn-muted);margin-top:.4rem;}
.tdn-media-ligne{display:flex;gap:.8rem;align-items:center;background:rgba(8,20,48,.6);border-radius:14px;padding:.8rem;}
.tdn-media-ligne b{display:block;font-size:.9rem;color:var(--tdn-creme);}
.tdn-media-ligne small{color:var(--tdn-muted);font-size:.75rem;}
.tdn-play{flex:0 0 2.6rem;height:2.6rem;border-radius:50%;display:grid;place-items:center;background:var(--tdn-or);color:var(--tdn-nuit);font-size:.9rem;padding-left:.2rem;}
.tdn-play-grand{width:4rem;height:4rem;font-size:1.5rem;}
.tdn-onde{margin-left:auto;display:flex;gap:2px;align-items:center;height:1.6rem;}
.tdn-onde i{width:3px;background:var(--tdn-or);border-radius:2px;opacity:.7;}
.tdn-question{font-size:1.15rem;font-weight:600;color:var(--tdn-creme);margin:.3rem 0 1rem;}
.tdn-choix{display:flex;flex-direction:column;gap:.55rem;}
.tdn-choix button{min-height:3.25rem;padding:.8rem 1rem;border-radius:12px;text-align:left;font-size:1rem;cursor:pointer;
  background:rgba(8,20,48,.6);border:2px solid rgba(255,255,255,.18);color:var(--tdn-creme);}
.tdn-choix button.on{border-color:var(--tdn-or);background:rgba(229,192,123,.15);}
.tdn-erreur{color:#f4a9b6;background:rgba(138,42,58,.25);border:1px solid rgba(138,42,58,.6);border-radius:12px;padding:.7rem .9rem;margin-top:.6rem;font-weight:600;}
.tdn-fieldset{border:1px solid rgba(255,255,255,.14);border-radius:12px;padding:.8rem 1rem .4rem;margin-top:1.2rem;}
.tdn-fieldset legend{padding:0 .4rem;}
.tdn-check{display:flex;align-items:center;gap:.8rem;min-height:2.8rem;font-size:1rem;cursor:pointer;}
.tdn-check input{width:1.4rem;height:1.4rem;accent-color:var(--tdn-or);}
.tdn-check-off{color:var(--tdn-muted);}
.tdn-check small{color:var(--tdn-muted);}
.tdn-indices{margin-top:1.4rem;padding:1.2rem;border-radius:var(--tdn-radius);border:1px dashed rgba(229,192,123,.4);}
.tdn-indices h3{font-size:1.05rem;color:var(--tdn-or);margin-bottom:.8rem;}
.tdn-indices .tdn-btn{width:100%;margin-top:.4rem;}
.tdn-indice{background:rgba(229,192,123,.1);border-radius:12px;padding:.8rem .9rem;margin-bottom:.6rem;animation:tdn-apparait .5s ease both;}
.tdn-indice p{margin-top:.25rem;color:var(--tdn-creme);}
.tdn-indice-secours{background:rgba(138,42,58,.2);}
.tdn-reussite{text-align:center;padding:2.2rem 1.3rem;border-color:rgba(229,192,123,.5);animation:tdn-apparait .6s ease both;}
.tdn-eclat{font-size:3rem;color:var(--tdn-or);animation:tdn-scintille 1.6s ease-in-out infinite;text-shadow:0 0 30px rgba(229,192,123,.7);}

/* Clé */
.tdn-cle{position:relative;overflow:hidden;border-radius:22px;padding:1.4rem;color:var(--tdn-nuit);
  background:linear-gradient(150deg,#f6e3b5 0%,var(--tdn-or) 40%,#b98a30 100%);
  box-shadow:0 20px 50px rgba(0,0,0,.45),inset 0 1px 0 rgba(255,255,255,.6);}
.tdn-cle .tdn-sur{color:rgba(8,20,48,.6);}
.tdn-cle-brillance{position:absolute;inset:-60%;pointer-events:none;
  background:linear-gradient(115deg,transparent 40%,rgba(255,255,255,.55) 50%,transparent 60%);
  animation:tdn-brillance 4.5s ease-in-out infinite;}
@keyframes tdn-brillance{0%{transform:translateX(-60%)}60%,100%{transform:translateX(60%)}}
.tdn-cle-haut{display:flex;justify-content:space-between;align-items:center;margin-bottom:.8rem;}
.tdn-cle .tdn-pastille{background:rgba(8,20,48,.15);color:var(--tdn-nuit);}
.tdn-cle .tdn-pastille-ok{background:var(--tdn-sapin);color:#fff;}
.tdn-cle-icone{width:4rem;height:2rem;color:var(--tdn-nuit);margin-bottom:.4rem;}
.tdn-cle-icone-vide{width:5rem;height:2.5rem;color:var(--tdn-or);opacity:.6;margin:1rem auto;}
.tdn-cle-num{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:2.4rem;line-height:1;margin-bottom:.8rem;}
.tdn-cle-code{font-family:'DM Mono',monospace;font-size:1.9rem;letter-spacing:.14em;margin:.2rem 0 1rem;font-weight:500;}
.tdn-cle-bas{display:flex;justify-content:space-between;align-items:flex-end;gap:1rem;border-top:1px solid rgba(8,20,48,.2);padding-top:.9rem;}
.tdn-cle-bas b{display:block;font-size:1rem;}
.tdn-cle-bas small{display:block;font-size:.72rem;color:rgba(8,20,48,.7);}
.tdn-qr{width:5.2rem;height:5.2rem;color:var(--tdn-nuit);background:var(--tdn-creme);padding:.3rem;border-radius:8px;flex:0 0 auto;}
.tdn-cle-grande{padding:1.7rem 1.5rem;}

/* Fin */
.tdn-fin{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;
  padding:2rem 1.2rem;overflow:hidden;
  background:radial-gradient(ellipse at 50% 30%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);}
.tdn-fin-inner{position:relative;z-index:2;width:100%;max-width:30rem;text-align:center;}
.tdn-fin-texte{font-size:clamp(2rem,8vw,3rem);color:var(--tdn-or);animation:tdn-apparait 1.2s ease both;text-shadow:0 0 30px rgba(229,192,123,.4);}
.tdn-lumiere-or{position:absolute;inset:0;pointer-events:none;
  background:radial-gradient(circle at 50% 55%,rgba(229,192,123,.45) 0%,rgba(229,192,123,.12) 30%,transparent 60%);
  animation:tdn-lumiere 2s ease-out both;}
@keyframes tdn-lumiere{from{opacity:0;transform:scale(.4)}to{opacity:1;transform:scale(1)}}
.tdn-fin-cle{animation:tdn-apparait 1s ease both;}
.tdn-fin-cle .tdn-cle{text-align:left;margin:1.5rem 0;}
.tdn-fin-msg{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:1.25rem;color:var(--tdn-creme);line-height:1.4;margin:1rem 0;}

/* Coffre (CSS pur) */
.tdn-coffre-scene{display:flex;flex-direction:column;align-items:center;gap:1.6rem;}
.tdn-coffre{position:relative;width:150px;height:110px;}
.tdn-coffre-xl{width:260px;height:190px;}
.tdn-coffre i{position:absolute;display:block;}
.tdn-coffre-corps{left:0;right:0;bottom:0;height:60%;background:linear-gradient(180deg,#6b2431,var(--tdn-bordeaux));
  border:3px solid var(--tdn-or);border-radius:0 0 12px 12px;box-shadow:inset 0 -10px 0 rgba(0,0,0,.25);}
.tdn-coffre-corps::after{content:"";position:absolute;left:50%;top:-2px;width:22%;height:40%;transform:translateX(-50%);
  background:var(--tdn-or);border-radius:0 0 6px 6px;}
.tdn-coffre-couvercle{left:0;right:0;top:0;height:44%;background:linear-gradient(180deg,#8a2a3a,#6b2431);
  border:3px solid var(--tdn-or);border-radius:60px 60px 0 0;transform-origin:50% 100%;transition:transform .9s cubic-bezier(.2,.8,.2,1);z-index:2;}
.tdn-coffre.ouvert .tdn-coffre-couvercle{transform:rotateX(-110deg) translateY(-8px);}
.tdn-coffre-lueur{left:10%;right:10%;top:20%;height:40%;border-radius:50%;opacity:0;
  background:radial-gradient(ellipse,rgba(255,236,180,.95),rgba(229,192,123,.4) 50%,transparent 75%);
  filter:blur(6px);transition:opacity .6s .5s,transform .8s .5s;transform:scale(.6);}
.tdn-coffre.ouvert .tdn-coffre-lueur{opacity:1;transform:scale(2.2);}

/* ---------- Révélation (grand écran) ---------- */
.tdn-revelation{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;
  padding:2rem 1.5rem;overflow:hidden;text-align:center;
  background:radial-gradient(ellipse at 50% 30%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);transition:background 1s;}
.tdn-revelation.tdn-grand{background:radial-gradient(ellipse at 50% 30%,#3d2a0f,var(--tdn-nuit) 75%);}
.tdn-rev-inner{position:relative;z-index:2;width:100%;max-width:56rem;}
.tdn-rev-titre{font-family:'Cormorant Garamond',serif;font-weight:700;text-transform:uppercase;letter-spacing:.06em;
  font-size:clamp(2.6rem,9vw,7rem);line-height:1;color:var(--tdn-or);margin:.6rem 0 1rem;
  text-shadow:0 0 50px rgba(229,192,123,.5);}
.tdn-rev-sous{font-size:clamp(1.2rem,3.5vw,2rem);color:var(--tdn-creme);margin-bottom:2rem;}
.tdn-rev-form{max-width:26rem;margin:0 auto 1.5rem;}
.tdn-rev-scene{display:flex;flex-direction:column;align-items:center;gap:2rem;}
.tdn-decompte{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(6rem,25vw,14rem);line-height:1;color:var(--tdn-or);
  animation:tdn-decompte 1s ease-out both;text-shadow:0 0 60px rgba(229,192,123,.6);}
@keyframes tdn-decompte{from{opacity:0;transform:scale(1.6)}30%{opacity:1;transform:scale(1)}to{opacity:.85}}
.tdn-rev-resultat{animation:tdn-apparait 1s ease both;}
.tdn-lot{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(2.2rem,8vw,6rem);line-height:1.05;
  color:var(--tdn-creme);margin:0 auto 1.5rem;max-width:20ch;padding:1.5rem;border-radius:26px;
  background:rgba(255,255,255,.06);border:2px solid rgba(229,192,123,.5);box-shadow:0 0 60px rgba(229,192,123,.25);}
.tdn-grand .tdn-lot{color:var(--tdn-or);border-color:var(--tdn-or);box-shadow:0 0 90px rgba(229,192,123,.5);}
.tdn-grand-tresor{display:inline-block;font-family:'DM Mono',monospace;text-transform:uppercase;letter-spacing:.3em;
  font-size:clamp(.9rem,2.5vw,1.4rem);color:var(--tdn-nuit);background:var(--tdn-or);padding:.6rem 1.4rem;border-radius:999px;
  animation:tdn-scintille 1.8s ease-in-out infinite;}
.tdn-rev-partenaire{font-size:clamp(1rem,3vw,1.6rem);color:var(--tdn-creme);margin-bottom:1.4rem;}
.tdn-rev-partenaire b{color:var(--tdn-or);}
.tdn-particules{position:absolute;inset:0;pointer-events:none;overflow:hidden;}
.tdn-particules i{position:absolute;top:-10px;width:8px;height:8px;border-radius:2px;background:var(--tdn-or);
  animation:tdn-particule 3.2s ease-in both;}
.tdn-particules i:nth-child(odd){background:var(--tdn-creme);width:5px;height:5px;border-radius:50%;}
@keyframes tdn-particule{0%{transform:translateY(0) rotate(0);opacity:0}10%{opacity:1}100%{transform:translateY(110vh) rotate(540deg);opacity:0}}

/* ---------- Nav basse ---------- */
.tdn-nav{position:fixed;left:0;right:0;bottom:0;z-index:40;display:flex;
  background:rgba(8,20,48,.92);backdrop-filter:blur(12px);border-top:1px solid rgba(255,255,255,.1);
  padding-bottom:env(safe-area-inset-bottom);}
.tdn-nav a{flex:1;display:flex;flex-direction:column;align-items:center;gap:.15rem;padding:.6rem 0 .5rem;
  text-decoration:none;font-size:.7rem;font-weight:600;color:var(--tdn-muted);min-height:3.6rem;}
.tdn-nav a span{font-size:1.25rem;}
.tdn-nav a.on{color:var(--tdn-or);}

/* ---------- Accessibilité / mouvement réduit ---------- */
@media (prefers-reduced-motion:reduce){
  .tdn *,.tdn *::before,.tdn *::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important;}
  .tdn-neige{display:none;}
  .tdn-traineau{display:none;}
}

/* ---------- Page réservation (avant ouverture) ---------- */
.tdn-resa .tdn-hero{padding-bottom:12rem;}
.tdn-resa .tdn-hero::after{content:"";position:absolute;left:0;right:0;bottom:0;height:9rem;pointer-events:none;z-index:1;
  background:linear-gradient(to bottom,transparent,var(--tdn-nuit));}
.tdn-resa .tdn-village{z-index:0;}
.tdn-traineau-boucle{animation:tdn-traineau-boucle 14s ease-in-out 1.5s infinite;}
@keyframes tdn-traineau-boucle{0%{left:-340px;top:14%;opacity:0}6%{opacity:1}55%{opacity:1}62%{left:110%;top:5%;opacity:0}100%{left:110%;opacity:0}}
.tdn-bientot{margin-top:1.6rem;display:inline-flex;align-items:center;gap:.7rem;padding:.55rem 1.1rem .55rem .7rem;border:1px solid rgba(229,192,123,.45);border-radius:999px;background:rgba(8,20,48,.5);font-size:.9rem;}
.tdn-bientot b{display:inline-grid;place-items:center;width:1.7rem;height:1.7rem;border-radius:50%;background:var(--tdn-or);color:var(--tdn-nuit);font-size:.8rem;}
.tdn-tresor{text-align:center;padding-top:3rem;}
.tdn-coffre-fixe{position:relative;margin-bottom:1.4rem;}
.tdn-lumiere-locale{position:absolute;left:50%;top:45%;width:300px;height:300px;transform:translate(-50%,-50%);inset:auto;animation:none;
  background:radial-gradient(circle,rgba(229,192,123,.35),rgba(229,192,123,.08) 45%,transparent 68%);}
.tdn-coffre-fixe .tdn-coffre{position:relative;width:170px;height:125px;}
.tdn-montant{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(4.5rem,16vw,9rem);line-height:1.1;color:var(--tdn-creme);text-shadow:0 0 50px rgba(229,192,123,.55);margin:.2rem 0 .4rem;}
.tdn-montant-multi{font-size:clamp(3.8rem,14vw,9rem);white-space:nowrap;}
.tdn-hotte{width:min(100%,420px);height:auto;display:block;margin:0 auto .4rem;}
.tdn-quoi{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:1.5rem;color:var(--tdn-creme);margin-top:.4rem;}
.tdn-comment{margin:1.2rem auto 0;max-width:46ch;color:var(--tdn-muted);}
.tdn-autres{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:1.35rem;color:var(--tdn-or);margin-top:2rem;}
.tdn-raisons{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:1rem;}
.tdn-raison{padding:1.5rem 1.3rem;border:1px solid rgba(255,255,255,.12);border-radius:18px;background:rgba(255,255,255,.05);}
.tdn-raison h3{font-family:'Cormorant Garamond',serif;font-weight:600;font-size:1.55rem;color:var(--tdn-creme);margin:.4rem 0;}
.tdn-raison p{color:var(--tdn-muted);font-size:.95rem;line-height:1.5;}
.tdn-raison-or{border-color:rgba(229,192,123,.55);background:linear-gradient(135deg,rgba(229,192,123,.2),rgba(138,42,58,.22));}
.tdn-raison-or h3{color:var(--tdn-or);}
.tdn-raison-or p{color:var(--tdn-texte);}
.tdn-carte-resa{max-width:34rem;margin:0 auto;padding:2.2rem 1.6rem;border-color:rgba(229,192,123,.4);box-shadow:0 20px 60px rgba(0,0,0,.4);position:relative;text-align:center;}
.tdn-carte-resa h2{font-size:2.2rem;}
.tdn-sceau{position:absolute;top:-1.1rem;left:50%;transform:translateX(-50%);width:2.2rem;height:2.2rem;display:grid;place-items:center;border-radius:50%;background:var(--tdn-or);color:var(--tdn-nuit);}
.tdn-centre-txt{text-align:center;}
.tdn-tarifs{display:grid;grid-template-columns:1fr 1fr;gap:.8rem;margin:1.4rem 0;}
.tdn-tarifs div{padding:1rem;border-radius:14px;background:rgba(8,20,48,.6);border:1px solid rgba(255,255,255,.12);}
.tdn-tarifs span{display:block;font-size:.8rem;color:var(--tdn-muted);}
.tdn-tarifs b{font-family:'Cormorant Garamond',serif;font-size:2.2rem;color:var(--tdn-creme);line-height:1.1;}
.tdn-jauge-txt{font-size:.9rem;color:var(--tdn-muted);margin-bottom:.4rem;}
.tdn-jauge-txt b{color:var(--tdn-or);}
.tdn-reglement h2{font-family:'Cormorant Garamond',serif;font-weight:600;font-size:1.5rem;color:var(--tdn-or);margin:2rem 0 .6rem;}
.tdn-reglement p{line-height:1.65;margin-bottom:.8rem;color:var(--tdn-texte);}
.tdn-reglement b{color:var(--tdn-creme);}
.tdn-reglement-lots{margin:0 0 1rem 1.3rem;line-height:1.7;color:var(--tdn-texte);}

/* ---------- Tirage du grand trésor ---------- */
.tdn-tirage{position:relative;min-height:100svh;display:flex;align-items:center;justify-content:center;padding:2rem 1.5rem;overflow:hidden;text-align:center;
  background:radial-gradient(ellipse at 50% 30%,var(--tdn-nuit-3),var(--tdn-nuit) 70%);}
.tdn-tirage-inner{position:relative;z-index:2;width:100%;max-width:80rem;display:flex;flex-direction:column;align-items:center;}
.tdn-tirage-halo{position:absolute;inset:0;pointer-events:none;opacity:0;transition:opacity 1.5s;
  background:radial-gradient(circle at 50% 50%,rgba(229,192,123,.45) 0%,rgba(229,192,123,.1) 30%,transparent 60%);}
.tdn-tirage.fini .tdn-tirage-halo{opacity:1;}
.tdn-tirage-admin{position:fixed;top:1rem;right:1rem;z-index:5;display:flex;gap:.5rem;font-size:.75rem;color:var(--tdn-muted);}
.tdn-tirage-admin span,.tdn-tirage-admin a{padding:.4rem .7rem;border:1px solid rgba(255,255,255,.15);border-radius:999px;background:rgba(8,20,48,.6);text-decoration:none;}
.tdn-tirage-compteur{margin-top:1rem;font-family:'DM Mono',monospace;color:var(--tdn-muted);font-size:clamp(.9rem,1.6vw,1.2rem);}
.tdn-tirage-compteur b{color:var(--tdn-or);font-size:1.5em;}
.tdn-mur{margin:1.6rem auto 0;display:grid;grid-template-columns:repeat(auto-fill,minmax(88px,1fr));gap:.5rem;width:100%;max-height:42vh;overflow:auto;padding:.6rem;scrollbar-width:none;
  -webkit-mask-image:linear-gradient(to bottom,#000 75%,transparent);mask-image:linear-gradient(to bottom,#000 75%,transparent);}
.tdn-cle-tuile{font-family:'DM Mono',monospace;font-size:clamp(.9rem,1.5vw,1.2rem);padding:.55rem .3rem;border:1px solid rgba(229,192,123,.3);border-radius:8px;background:rgba(255,255,255,.04);color:var(--tdn-creme);transition:transform .15s,background .15s;}
.tdn-cle-tuile small{display:block;font-family:'Bricolage Grotesque',sans-serif;font-size:.7em;color:var(--tdn-muted);margin-top:.15rem;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
.tdn-cle-tuile.on{background:var(--tdn-or);color:var(--tdn-nuit);transform:scale(1.15);box-shadow:0 0 30px rgba(229,192,123,.7);position:relative;z-index:2;}
.tdn-cle-tuile.on small{color:rgba(8,20,48,.7);}
.tdn-tambour{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(6rem,22vw,16rem);line-height:1;color:var(--tdn-creme);text-shadow:0 0 60px rgba(229,192,123,.6);letter-spacing:.05em;font-variant-numeric:tabular-nums;}
.tdn-tambour span{display:inline-block;min-width:.62em;}
.tdn-tirage-resultat{animation:tdn-apparait 1s ease both;}
.tdn-gagnant{margin:1.2rem 0 .6rem;padding:2rem 3rem;border-radius:26px;border:2px solid var(--tdn-or);background:rgba(255,255,255,.06);box-shadow:0 0 90px rgba(229,192,123,.45);}
.tdn-gagnant-num{font-family:'Cormorant Garamond',serif;font-weight:700;font-size:clamp(3rem,12vw,9rem);line-height:1;color:var(--tdn-creme);text-shadow:0 0 50px rgba(229,192,123,.6);}
.tdn-gagnant-nom{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:clamp(1.6rem,4vw,3rem);color:var(--tdn-or);margin-top:.3rem;}
.tdn-gagnant-famille{color:var(--tdn-muted);font-size:clamp(1rem,2vw,1.4rem);}


/* ---------- Tirage : plusieurs lots, un gagnant dévoilé après l'autre ---------- */
.tdn-tirage-etape{font-family:'DM Mono',monospace;text-transform:uppercase;letter-spacing:.2em;font-size:clamp(.8rem,1.5vw,1.15rem);
  color:var(--tdn-nuit);background:var(--tdn-or);padding:.45rem 1.1rem;border-radius:999px;margin-bottom:1.2rem;}
.tdn-cle-tuile.tiree{border-color:var(--tdn-or);background:rgba(229,192,123,.16);color:var(--tdn-or);opacity:.6;}
.tdn-gagnant-lot{font-family:'Cormorant Garamond',serif;font-style:italic;font-size:clamp(1.3rem,3vw,2.2rem);color:var(--tdn-creme);margin-top:.4rem;}
.tdn-gagnant-rang{font-family:'DM Mono',monospace;text-transform:uppercase;letter-spacing:.18em;font-size:clamp(.7rem,1.1vw,.9rem);color:var(--tdn-or);margin-bottom:.5rem;}
.tdn-podium{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:1.2rem;width:100%;max-width:72rem;margin:1.4rem 0 1.6rem;}
.tdn-podium .tdn-gagnant{margin:0;padding:1.5rem 1rem;box-shadow:0 0 60px rgba(229,192,123,.35);}
.tdn-podium .tdn-gagnant-num{font-size:clamp(2.2rem,5vw,4.6rem);}
.tdn-podium .tdn-gagnant-nom{font-size:clamp(1.4rem,2.6vw,2.3rem);}
.tdn-podium .tdn-gagnant-famille{font-size:clamp(.9rem,1.4vw,1.15rem);}
.tdn-lot.tdn-lot-recap{font-size:clamp(1.4rem,3.2vw,2.6rem);max-width:none;padding:1rem 1.6rem;margin-bottom:1rem;color:var(--tdn-or);border-color:var(--tdn-or);}
.tdn-podium ~ .tdn-rev-sous{margin-bottom:1.2rem;}
/* Présentation et récapitulatif peuvent dépasser l'écran (portable, mobile) : on les laisse défiler
   au lieu de les rogner, pour que les boutons restent toujours atteignables. */
.tdn-tirage.defile{height:100svh;min-height:0;overflow-y:auto;align-items:flex-start;}
.tdn-tirage.defile .tdn-tirage-inner{margin:auto 0;}
@media (max-width:700px){.tdn-tirage.defile{padding-top:4.5rem;}}
EOF_PN_FICHIER
echo "  ✓ src/app/tresors-de-noel/tresors.css"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/FormInscription.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState, useState } from 'react';
import { inscrire, type Etat } from '@/app/tresors-actions';
import { euros } from '@/lib/sumup';
import type { Categorie } from '@/lib/tresors/types';

type Ligne = { id: number; prenom: string; categorie: Categorie };

/**
 * Inscription en 3 écrans dans un seul formulaire : responsable → participants → récapitulatif/paiement.
 * Règle : au moins un adulte inscrit pour pouvoir inscrire des enfants (revérifiée côté serveur).
 */
export default function FormInscription({ tarifAdulte, tarifEnfant }: { tarifAdulte: number; tarifEnfant: number }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(inscrire, null);
  const [etape, setEtape] = useState(1);
  const [resp, setResp] = useState({ prenom: '', nom: '', email: '', telephone: '' });
  const [lignes, setLignes] = useState<Ligne[]>([{ id: 1, prenom: '', categorie: 'adulte' }]);
  const tarif = (c: Categorie) => (c === 'adulte' ? tarifAdulte : tarifEnfant);
  const total = lignes.reduce((s, l) => s + tarif(l.categorie), 0);
  const respOk = resp.prenom && resp.nom && resp.email.includes('@');
  const nbAdultes = lignes.filter((l) => l.categorie === 'adulte').length;
  /** Le dernier adulte de la liste ne peut ni passer en « enfant » ni être retiré. */
  const seulAdulte = (l: Ligne) => l.categorie === 'adulte' && nbAdultes === 1;
  const lignesOk = lignes.length > 0 && nbAdultes >= 1 && lignes.every((l) => l.prenom.trim());
  const maj = (id: number, patch: Partial<Ligne>) => setLignes((ls) => ls.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  return (
    <form action={action}>
      <div className="tdn-stepper" aria-hidden="true">{[1, 2, 3].map((n) => <span key={n} className={n <= etape ? 'on' : ''} />)}</div>
      {etat?.erreur && <p className="tdn-erreur" role="alert">{etat.erreur}</p>}

      <section className="tdn-carte" hidden={etape !== 1}>
        <h2>Le responsable</h2>
        <p className="tdn-muted">La personne qui gère le compte et reçoit les e-mails.</p>
        <div className="tdn-champ"><label htmlFor="prenom">Prénom</label>
          <input id="prenom" name="prenom" autoComplete="given-name" value={resp.prenom} onChange={(e) => setResp({ ...resp, prenom: e.target.value })} /></div>
        <div className="tdn-champ"><label htmlFor="nom">Nom</label>
          <input id="nom" name="nom" autoComplete="family-name" value={resp.nom} onChange={(e) => setResp({ ...resp, nom: e.target.value })} /></div>
        <div className="tdn-champ"><label htmlFor="email">E-mail</label>
          <input id="email" name="email" type="email" inputMode="email" autoComplete="email" value={resp.email} onChange={(e) => setResp({ ...resp, email: e.target.value })} /></div>
        <div className="tdn-champ"><label htmlFor="tel">Téléphone (optionnel)</label>
          <input id="tel" name="telephone" type="tel" inputMode="tel" autoComplete="tel" value={resp.telephone} onChange={(e) => setResp({ ...resp, telephone: e.target.value })} /></div>
        <button type="button" className="tdn-btn tdn-btn-or tdn-btn-large" disabled={!respOk} onClick={() => setEtape(2)}>Continuer</button>
      </section>

      <section className="tdn-carte" hidden={etape !== 2}>
        <h2>Les participants</h2>
        <p className="tdn-muted">Chaque participant reçoit sa propre clé à la fin. Adulte {euros(tarifAdulte)}, enfant {euros(tarifEnfant)}.</p>
        <p className="tdn-regle-adulte"><b>Au moins un adulte</b> doit être inscrit pour pouvoir inscrire des enfants.</p>
        {lignes.map((l, i) => (
          <div key={l.id} className="tdn-ligne-part">
            <div className="tdn-champ" style={{ flex: 1 }}>
              <label htmlFor={`p${l.id}`}>Participant {i + 1}</label>
              <input id={`p${l.id}`} name="participant_prenom" placeholder="Prénom" value={l.prenom} onChange={(e) => maj(l.id, { prenom: e.target.value })} />
              <input type="hidden" name="participant_categorie" value={l.categorie} />
            </div>
            <div className="tdn-toggle" role="radiogroup" aria-label="Catégorie">
              <button type="button" className={l.categorie === 'adulte' ? 'on' : ''} onClick={() => maj(l.id, { categorie: 'adulte' })}>Adulte</button>
              <button type="button" className={l.categorie === 'enfant' ? 'on' : ''} disabled={seulAdulte(l)}
                title={seulAdulte(l) ? 'Au moins un adulte doit être inscrit' : undefined} onClick={() => maj(l.id, { categorie: 'enfant' })}>Enfant</button>
            </div>
            {lignes.length > 1 && (
              <button type="button" className="tdn-suppr" aria-label="Supprimer" disabled={seulAdulte(l)}
                title={seulAdulte(l) ? 'Au moins un adulte doit être inscrit' : undefined} onClick={() => setLignes((ls) => ls.filter((x) => x.id !== l.id))}>✕</button>
            )}
          </div>
        ))}
        <button type="button" className="tdn-btn tdn-btn-ghost" onClick={() => setLignes((ls) => [...ls, { id: Date.now(), prenom: '', categorie: 'enfant' }])}>+ Ajouter un participant</button>
        <div className="tdn-actions">
          <button type="button" className="tdn-btn tdn-btn-ghost" onClick={() => setEtape(1)}>Retour</button>
          <button type="button" className="tdn-btn tdn-btn-or" disabled={!lignesOk} onClick={() => setEtape(3)}>Continuer</button>
        </div>
      </section>

      <section className="tdn-carte" hidden={etape !== 3}>
        <h2>Récapitulatif</h2>
        <p className="tdn-muted">Responsable : {resp.prenom} {resp.nom} · {resp.email}</p>
        <ul className="tdn-recap">
          {lignes.map((l) => <li key={l.id}><span>{l.prenom} <small>({l.categorie})</small></span><b>{euros(tarif(l.categorie))}</b></li>)}
          <li className="tdn-recap-total"><span>Total</span><b>{euros(total)}</b></li>
        </ul>
        <button type="submit" className="tdn-btn tdn-btn-or tdn-btn-large" disabled={pending}>
          {pending ? 'Redirection vers le paiement…' : `Payer ${euros(total)}`}
        </button>
        <p className="tdn-muted tdn-mini">Paiement sécurisé par SumUp. Vous serez redirigé vers la page de paiement.</p>
        <button type="button" className="tdn-lien" onClick={() => setEtape(2)}>Modifier les participants</button>
      </section>
    </form>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/FormInscription.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/FormReglagesTdn.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState } from 'react';
import { majReglagesTdn, type Etat } from '@/app/tresors-actions';
import { nombreGrandTresor, type Reglages } from '@/lib/tresors/types';

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
        <div className="row3">
          <div className="field"><label htmlFor="grand_tresor_nombre">Nombre de lots (gagnants tirés au sort)</label><input id="grand_tresor_nombre" name="grand_tresor_nombre" type="number" min={1} max={50} step={1} defaultValue={nombreGrandTresor(r)} /></div>
          <div className="field"><label htmlFor="grand_tresor_montant">Montant d&apos;un lot</label><input id="grand_tresor_montant" name="grand_tresor_montant" defaultValue={r.grand_tresor_montant} placeholder="100 €" /></div>
          <div className="field"><label htmlFor="grand_tresor_texte">Description</label><input id="grand_tresor_texte" name="grand_tresor_texte" defaultValue={r.grand_tresor_texte} placeholder="3 cartes cadeaux multi-enseignes" /></div>
        </div>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginBottom: '1rem' }}>Exemple : 3 lots à 100 € s&apos;affichent « 3 × 100 € » sur la page du jeu, et le tirage désigne 3 clés gagnantes différentes.</p>
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
          <input type="checkbox" name="grand" defaultChecked={lot?.grand ?? false} style={{ width: 'auto' }} /> Grand trésor (hors révélation, tirage au sort dédié)
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
cat > 'src/components/tresors/Hotte.tsx' <<'EOF_PN_FICHIER'
/** Hotte du Père Noël débordant de cadeaux, avec son halo intégré (rien ne déborde du SVG). */
export default function Hotte({ className = '', etiquette = '' }: { className?: string; etiquette?: string }) {
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

      {/* cadeaux qui dépassent */}
      <g transform="rotate(-12 150 118)"><rect x="118" y="88" width="62" height="60" rx="5" fill="url(#hotte-vert)" /><rect x="118" y="112" width="62" height="12" fill="url(#hotte-or)" /><rect x="143" y="88" width="12" height="60" fill="url(#hotte-or)" /></g>
      <g transform="rotate(10 250 108)"><rect x="216" y="70" width="70" height="72" rx="5" fill="url(#hotte-bleu)" /><rect x="216" y="100" width="70" height="12" fill="#fbf7ef" /><rect x="245" y="70" width="12" height="72" fill="#fbf7ef" /><path d="M251 66 c-12 -14 -28 -2 -10 6 c-18 0 -8 -18 10 -6 c18 -12 28 6 10 6 c18 -8 2 -20 -10 -6z" fill="#fbf7ef" /></g>
      <rect x="180" y="96" width="48" height="52" rx="5" fill="url(#hotte-or)" /><rect x="180" y="118" width="48" height="10" fill="#8a2a3a" /><rect x="199" y="96" width="10" height="52" fill="#8a2a3a" />
      {/* sucre d'orge */}
      <path d="M292 122 c0 -30 24 -32 26 -12" fill="none" stroke="#fbf7ef" strokeWidth="9" strokeLinecap="round" />
      <path d="M292 122 c0 -30 24 -32 26 -12" fill="none" stroke="#c22a45" strokeWidth="9" strokeLinecap="round" strokeDasharray="7 7" />

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
      <g fill="#fbf7ef"><path d="M70 90 l3 8 8 3 -8 3 -3 8 -3 -8 -8 -3 8 -3z" /><path d="M330 60 l2.5 6.5 6.5 2.5 -6.5 2.5 -2.5 6.5 -2.5 -6.5 -6.5 -2.5 6.5 -2.5z" /><path d="M320 200 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z" /></g>
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
          {!connecte && <p className="tdn-mini" style={{ marginTop: '1rem' }}><Link href="/tresors-de-noel/acces" className="tdn-lien">Déjà inscrit ? Retrouver mon compte</Link></p>}
        </div>
        <Village />
      </section>

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
import Hotte from './Hotte';
import { euros } from '@/lib/sumup';
import { enLettres, montantGrandTresor, nombreGrandTresor, type Reglages } from '@/lib/tresors/types';

const dateLongue = (iso: string | null) => iso ? new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', timeZone: 'Europe/Paris' }).format(new Date(iso)) : '';

/** Page d'attente avant l'ouverture du jeu : réservation payante, places limitées, grand trésor. */
export default function LandingReservation({ reglages: r, connecte, placesRestantes }: { reglages: Reglages; connecte: boolean; placesRestantes: number }) {
  const complet = placesRestantes <= 0;
  const pct = r.places_max > 0 ? Math.round((placesRestantes / r.places_max) * 100) : 0;
  const debut = dateLongue(r.jeu_debut);
  // Grand trésor : un ou plusieurs lots identiques, une clé gagnante par lot.
  const nbGrand = nombreGrandTresor(r);
  const montantGrand = montantGrandTresor(r);

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

      <section className="tdn-section tdn-tresor" id="tresor">
        <Hotte className="tdn-hotte" etiquette={montantGrand} />
        <h2 className="tdn-h2">Le grand trésor</h2>
        <p className="tdn-quoi">{r.grand_tresor_texte}</p>
        <div className={`tdn-montant${nbGrand > 1 ? ' tdn-montant-multi' : ''}`}>{montantGrand}</div>
        {nbGrand > 1 ? (
          <p className="tdn-comment">Il se cache dans {enLettres(nbGrand)} des clés remises lors de la révélation. Toutes les clés ouvrent un trésor : {enLettres(nbGrand)} d&apos;entre elles, tirées au sort, ouvrent celui-là.</p>
        ) : (
          <p className="tdn-comment">Il se cache dans l&apos;une des clés remises lors de la révélation. Toutes les clés ouvrent un trésor : l&apos;une d&apos;elles ouvre celui-là.</p>
        )}
        <p className="tdn-autres">…et de nombreux autres lots, un pour chaque participant qui termine l&apos;aventure.</p>
      </section>

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
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/Participants.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState, useState, useTransition } from 'react';
import { ajouterParticipant, choisirParticipant, payerEnAttente, supprimerParticipant, type Etat } from '@/app/tresors-actions';
import { euros } from '@/lib/sumup';
import type { Categorie, Progression } from '@/lib/tresors/types';
import { numeroCle } from '@/lib/tresors/types';

type Props = { progressions: Progression[]; actifId: string | null; nbMissions: number; tarifAdulte: number; tarifEnfant: number; inscriptionsOuvertes: boolean };

export default function Participants({ progressions, actifId, nbMissions, tarifAdulte, tarifEnfant, inscriptionsOuvertes }: Props) {
  const [etat, action, pending] = useActionState<Etat, FormData>(ajouterParticipant, null);
  // Règle : au moins un adulte sur le compte pour pouvoir ajouter des enfants (revérifiée côté serveur).
  const aUnAdulte = progressions.some((p) => p.participant.categorie === 'adulte');
  const [choix, setCategorie] = useState<Categorie>(aUnAdulte ? 'enfant' : 'adulte');
  const categorie: Categorie = aUnAdulte ? choix : 'adulte';
  const [, start] = useTransition();
  const [erreurPaiement, setErreurPaiement] = useState('');
  const [erreurRetrait, setErreurRetrait] = useState('');
  const nonPayes = progressions.filter((p) => !p.participant.paye);
  const montant = nonPayes.reduce((s, p) => s + (p.participant.categorie === 'adulte' ? tarifAdulte : tarifEnfant), 0);

  return (
    <section className="tdn-carte">
      <h2>Participants</h2>
      <ul className="tdn-participants">
        {progressions.map(({ participant: p, missionsValidees, cle }) => {
          const actif = p.id === actifId;
          return (
            <li key={p.id} className={actif ? 'on' : ''}>
              <button type="button" className="tdn-part-sel" aria-pressed={actif} onClick={() => start(() => choisirParticipant(p.id))}>
                <span className="tdn-avatar">{p.prenom[0]}</span>
                <span className="tdn-part-info">
                  <b>{p.prenom}</b>
                  <small>{p.categorie === 'adulte' ? 'Adulte' : 'Enfant'} · {p.paye ? 'Inscrit' : 'En attente de paiement'}</small>
                  <span className="tdn-barre tdn-barre-mini"><i style={{ width: `${(missionsValidees.length / Math.max(nbMissions, 1)) * 100}%` }} /></span>
                  <small>{missionsValidees.length} / {nbMissions} missions{cle && ` · Clé n° ${numeroCle(cle.numero)}`}</small>
                </span>
                {actif && <span className="tdn-pastille">Actif</span>}
              </button>
              {!p.paye && (
                <button type="button" className="tdn-suppr" aria-label={`Retirer ${p.prenom}`} onClick={() => start(async () => { const r = await supprimerParticipant(p.id); setErreurRetrait(r?.erreur ?? ''); })}>✕</button>
              )}
            </li>
          );
        })}
      </ul>
      {erreurRetrait && <p className="tdn-erreur" role="alert">{erreurRetrait}</p>}

      {nonPayes.length > 0 && (
        <div className="tdn-indice" style={{ marginTop: '1rem' }}>
          <div className="tdn-sur">Paiement en attente</div>
          <p>{nonPayes.map((p) => p.participant.prenom).join(', ')} · {euros(montant)}</p>
          {erreurPaiement && <p className="tdn-erreur">{erreurPaiement}</p>}
          <button type="button" className="tdn-btn tdn-btn-or tdn-btn-large" style={{ marginTop: '.6rem' }}
            onClick={() => start(async () => { const r = await payerEnAttente(); if (r?.erreur) setErreurPaiement(r.erreur); })}>
            Payer {euros(montant)}
          </button>
        </div>
      )}

      {inscriptionsOuvertes && (
        <form action={action} style={{ marginTop: '1.2rem' }}>
          {etat?.ok && <p className="tdn-indice">{etat.ok}</p>}
          {etat?.erreur && <p className="tdn-erreur">{etat.erreur}</p>}
          <div className="tdn-ligne-part">
            <div className="tdn-champ" style={{ flex: 1 }}>
              <label htmlFor="np">Ajouter un participant</label>
              <input id="np" name="prenom" placeholder="Prénom" required />
              <input type="hidden" name="categorie" value={categorie} />
            </div>
            <div className="tdn-toggle">
              <button type="button" className={categorie === 'adulte' ? 'on' : ''} onClick={() => setCategorie('adulte')}>Adulte</button>
              <button type="button" className={categorie === 'enfant' ? 'on' : ''} disabled={!aUnAdulte}
                title={aUnAdulte ? undefined : 'Ajoutez d’abord un adulte'} onClick={() => setCategorie('enfant')}>Enfant</button>
            </div>
          </div>
          {!aUnAdulte && <p className="tdn-regle-adulte"><b>Au moins un adulte</b> doit être inscrit pour pouvoir ajouter des enfants.</p>}
          <button className="tdn-btn tdn-btn-ghost" disabled={pending}>+ Ajouter ({euros(categorie === 'adulte' ? tarifAdulte : tarifEnfant)})</button>
        </form>
      )}
    </section>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/Participants.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/TableCles.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useTransition } from 'react';
import { majCle } from '@/app/tresors-actions';
import { numeroCle, type Lot } from '@/lib/tresors/types';

type Ligne = { id: string; numero: number; code: string; prenom: string; famille: string; lot_id: string | null; lot: string; revelee: boolean };

export default function TableCles({ lignes, lots }: { lignes: Ligne[]; lots: Lot[] }) {
  const [pending, start] = useTransition();

  function exporter() {
    const rows = [['numero', 'code', 'prenom', 'famille', 'lot', 'revelee'], ...lignes.map((l) => [numeroCle(l.numero), l.code, l.prenom, l.famille, l.lot, l.revelee ? 'oui' : 'non'])];
    const csv = rows.map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(';')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })); a.download = 'cles-tresors-de-noel.csv'; a.click();
  }

  return (
    <div className="panel" style={{ opacity: pending ? .7 : 1 }}>
      <div style={{ textAlign: 'right', marginBottom: '1rem' }}><button className="btn btn-k btn-sm" onClick={exporter}>Exporter les clés</button></div>
      <table className="tbl">
        <thead><tr><th>N°</th><th>Code</th><th>Participant</th><th>Famille</th><th>Lot</th><th>Révélée</th></tr></thead>
        <tbody>
          {lignes.map((l) => (
            <tr key={l.id}>
              <td className="mono">{numeroCle(l.numero)}</td><td className="mono">{l.code}</td><td><b>{l.prenom}</b></td><td>{l.famille}</td>
              <td>
                <select value={l.lot_id ?? ''} onChange={(e) => start(() => majCle(l.id, { lot_id: e.target.value || null }))} style={{ padding: '.4rem', border: '2px solid var(--noir)' }}>
                  <option value="">Tirage au sort à la révélation</option>
                  {lots.map((lot) => <option key={lot.id} value={lot.id}>{lot.grand ? '★ ' : ''}{lot.nom}</option>)}
                </select>
              </td>
              <td>
                <button className={`pill ${l.revelee ? 'done' : 'off'}`} style={{ cursor: 'pointer' }} onClick={() => start(() => majCle(l.id, { revelee: !l.revelee }))}>
                  {l.revelee ? 'oui' : 'non'}
                </button>
              </td>
            </tr>
          ))}
          {lignes.length === 0 && <tr><td colSpan={6}>Aucune clé générée pour le moment.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/TableCles.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/TableParticipants.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useState, useTransition } from 'react';
import { marquerPaye, supprimerParticipantAdmin } from '@/app/tresors-actions';
import { numeroCle } from '@/lib/tresors/types';

type Ligne = { id: string; prenom: string; categorie: string; paye: boolean; responsable: string; email: string; telephone: string; progression: number; cle: number | null; statut: string };

export default function TableParticipants({ lignes, nbMissions }: { lignes: Ligne[]; nbMissions: number }) {
  const [q, setQ] = useState('');
  const [, start] = useTransition();
  const f = q.trim().toLowerCase();
  const vis = lignes.filter((l) => !f || `${l.prenom} ${l.responsable} ${l.email}`.toLowerCase().includes(f));
  const pill = (s: string) => (s === 'révélé' || s === 'terminé' ? 'done' : s === 'en cours' ? 'new' : 'off');

  function exporter() {
    const rows = [['prenom', 'categorie', 'paye', 'responsable', 'email', 'telephone', 'progression', 'cle', 'statut'],
      ...lignes.map((l) => [l.prenom, l.categorie, l.paye ? 'oui' : 'non', l.responsable, l.email, l.telephone, `${l.progression}/${nbMissions}`, l.cle ? numeroCle(l.cle) : '', l.statut])];
    const csv = rows.map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(';')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })); a.download = 'participants-tresors.csv'; a.click();
  }

  return (
    <div className="panel">
      <div style={{ display: 'flex', gap: '.8rem', justifyContent: 'space-between', flexWrap: 'wrap', marginBottom: '1rem' }}>
        <input placeholder="Rechercher un prénom, un responsable, un e-mail…" value={q} onChange={(e) => setQ(e.target.value)} style={{ flex: 1, minWidth: 240, padding: '.6rem .8rem', border: '2px solid var(--noir)' }} />
        <button className="btn btn-k btn-sm" onClick={exporter}>Exporter CSV</button>
      </div>
      <table className="tbl">
        <thead><tr><th>Prénom</th><th>Cat.</th><th>Responsable</th><th>Contact</th><th>Progression</th><th>Clé</th><th>Statut</th><th></th></tr></thead>
        <tbody>
          {vis.map((l) => (
            <tr key={l.id}>
              <td><b>{l.prenom}</b></td><td>{l.categorie}</td><td>{l.responsable}</td>
              <td style={{ fontSize: '.8rem' }}>{l.email}<br />{l.telephone}</td>
              <td>{l.progression} / {nbMissions}</td><td className="mono">{l.cle ? numeroCle(l.cle) : '—'}</td>
              <td><span className={`pill ${pill(l.statut)}`}>{l.statut}</span></td>
              <td style={{ whiteSpace: 'nowrap' }}>
                <button className="btn btn-w btn-sm" onClick={() => start(() => marquerPaye(l.id, !l.paye))}>{l.paye ? 'Marquer non payé' : 'Marquer payé'}</button>{' '}
                <button className="btn btn-w btn-sm" onClick={() => { if (confirm(`Supprimer ${l.prenom} ?`)) start(() => supprimerParticipantAdmin(l.id)); }}>✕</button>
              </td>
            </tr>
          ))}
          {vis.length === 0 && <tr><td colSpan={8}>Aucun participant.</td></tr>}
        </tbody>
      </table>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/TableParticipants.tsx"
mkdir -p 'src/components/tresors'
cat > 'src/components/tresors/Tirage.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Neige from './Neige';
import { tirerGrandTresor, annulerTirage, type Gagnant } from '@/app/tresors-actions';
import { numeroCle } from '@/lib/tresors/types';

type CleT = { id: string; numero: number; prenom: string; famille: string };
/** presentation → (balayage → tambour → gagnant) pour chaque lot → final (tous les gagnants). */
type Phase = 'presentation' | 'balayage' | 'tambour' | 'gagnant' | 'final';
type Props = {
  cles: CleT[];
  /** Nombre de lots à attribuer = nombre de clés tirées au sort. */
  nombre: number;
  /** Description de l'ensemble du grand trésor, ex. « 3 cartes cadeaux multi-enseignes de 100 € ». */
  lot: string;
  /** Libellé d'un lot, ex. « Carte cadeau multi-enseignes de 100 € ». */
  lotUnitaire: string;
  tirageFait: boolean;
};

const dodo = (ms: number) => new Promise((r) => setTimeout(r, ms));
const PHRASES = ['Le lutin fouille dans la hotte…', 'Il hésite…', 'Il a trouvé quelque chose…', 'Il la tient !'];

export default function Tirage({ cles, nombre, lot, lotUnitaire, tirageFait }: Props) {
  const [phase, setPhase] = useState<Phase>('presentation');
  const [allumee, setAllumee] = useState<string | null>(null);
  const [chiffres, setChiffres] = useState(['0', '0', '0']);
  const [suspense, setSuspense] = useState(PHRASES[0]);
  const [gagnants, setGagnants] = useState<Gagnant[]>([]);
  const [index, setIndex] = useState(0);
  const [erreur, setErreur] = useState('');
  const [occupe, setOccupe] = useState(false);
  const [deverrouille, setDeverrouille] = useState(!tirageFait);
  const murRef = useRef<HTMLDivElement>(null);

  const total = gagnants.length || Math.min(nombre, Math.max(cles.length, 1));
  const plusieurs = total > 1;
  const gagnant = gagnants[index] ?? null;
  const dejaSorties = new Set(gagnants.slice(0, index).map((g) => g.cleId));

  /** Dévoile le gagnant n° i : balayage du mur de clés, puis tambour chiffre par chiffre. */
  async function devoiler(i: number, liste: Gagnant[]) {
    const g = liste[i];
    if (!g) { setPhase('final'); return; }
    setIndex(i);
    const reduit = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!reduit) {
      setAllumee(null);
      setPhase('balayage');
      const sorties = new Set(liste.slice(0, i).map((x) => x.cleId));
      const enLice = cles.filter((c) => !sorties.has(c.id));
      for (let k = 0; k < 45 && enLice.length > 0; k++) {
        const c = enLice[Math.floor(Math.random() * enLice.length)];
        setAllumee(c.id);
        murRef.current?.querySelector<HTMLElement>(`[data-id="${c.id}"]`)?.scrollIntoView({ block: 'nearest' });
        await dodo(k < 30 ? 45 : 45 + (k - 30) * 25);
      }
      const cible = numeroCle(g.numero).split('');
      const fixes = cible.map(() => '');
      setChiffres(cible.map(() => '0'));
      setPhase('tambour');
      for (let k = 0; k < cible.length; k++) {
        setSuspense(PHRASES[Math.min(k, PHRASES.length - 1)]);
        for (let t = 0; t < 18 + k * 6; t++) {
          setChiffres(fixes.map((f, j) => (j < k ? f : String(Math.floor(Math.random() * 10)))));
          await dodo(70 + k * 30);
        }
        fixes[k] = cible[k];
        setChiffres(fixes.map((f, j) => (j <= k ? cible[j] : f)));
        await dodo(500);
      }
      await dodo(900);
    }
    setPhase('gagnant');
  }

  /** Le serveur décide et enregistre d'abord tous les gagnants ; l'animation ne fait que les dévoiler un par un. */
  async function lancer(direct = false) {
    if (phase !== 'presentation' || occupe) return;
    setErreur(''); setOccupe(true);
    const r = await tirerGrandTresor();
    setOccupe(false);
    if (!r.ok) { setErreur(r.erreur); return; }
    if (r.gagnants.length === 0) { setErreur('Les clés gagnantes sont introuvables. Annulez le tirage et relancez-le.'); return; }
    setGagnants(r.gagnants);
    if (direct) { setIndex(r.gagnants.length - 1); setPhase(r.gagnants.length > 1 ? 'final' : 'gagnant'); return; }
    await devoiler(0, r.gagnants);
  }

  async function relancer() {
    if (!confirm(`Annuler le tirage enregistré et en refaire un ? ${nombre > 1 ? 'Les lots seront retirés aux clés gagnantes actuelles.' : 'Le lot sera retiré à la clé actuelle.'}`)) return;
    await annulerTirage();
    setDeverrouille(true); setGagnants([]); setIndex(0); setPhase('presentation');
  }

  useEffect(() => { document.body.style.overflow = 'hidden'; return () => { document.body.style.overflow = ''; }; }, []);

  const fini = phase === 'gagnant' || phase === 'final';
  const titre = 'Le tirage du Grand Trésor';
  const etape = plusieurs ? `Grand Trésor · lot ${index + 1} sur ${total}` : null;

  return (
    <main className={`tdn-tirage${fini ? ' fini' : ''}${phase === 'presentation' || phase === 'final' ? ' defile' : ''}`}>
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={45} />
      <div className="tdn-tirage-halo" aria-hidden="true" />
      <div className="tdn-tirage-admin">
        <span>Écran admin</span>
        <span>{fini ? 'Tirage enregistré' : tirageFait && !deverrouille ? 'Tirage déjà effectué' : `${cles.length} clés en lice`}</span>
        <Link href="/tresors-de-noel/revelation">Écran de révélation</Link>
      </div>

      {phase === 'presentation' && (
        <section className="tdn-tirage-inner">
          <div className="tdn-sur tdn-sur-grand">Les Trésors de Noël de Limetz-Villez</div>
          <h1 className="tdn-rev-titre">{titre}</h1>
          <p className="tdn-rev-sous">
            {lot}. {nombre > 1 ? `${nombre} clés différentes sont tirées au sort parmi toutes les clés du jeu, une par lot.` : 'Toutes les clés générées pendant le jeu participent au tirage.'}
          </p>
          <p className="tdn-tirage-compteur"><b>{cles.length}</b> clé{cles.length > 1 ? 's' : ''} en lice</p>
          <div className="tdn-mur" ref={murRef}>
            {cles.map((c) => <div key={c.id} data-id={c.id} className="tdn-cle-tuile">{numeroCle(c.numero)}<small>{c.prenom}</small></div>)}
          </div>
          {cles.length > 0 && cles.length < nombre && <p className="tdn-erreur">Seulement {cles.length} clé{cles.length > 1 ? 's' : ''} en lice pour {nombre} lots : {cles.length > 1 ? `${cles.length} lots seront attribués` : 'un seul lot sera attribué'}.</p>}
          {erreur && <p className="tdn-erreur" role="alert">{erreur}</p>}
          {tirageFait && !deverrouille ? (
            <div className="tdn-actions tdn-actions-col" style={{ maxWidth: '28rem', margin: '1.5rem auto 0' }}>
              <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={() => lancer()} disabled={occupe}>Revoir le résultat</button>
              {nombre > 1 && <button className="tdn-btn tdn-btn-ghost" onClick={() => lancer(true)} disabled={occupe}>Afficher directement les gagnants</button>}
              <button className="tdn-btn tdn-btn-ghost" onClick={relancer} disabled={occupe}>Annuler et refaire le tirage</button>
            </div>
          ) : (
            <button className="tdn-btn tdn-btn-or tdn-btn-xl" style={{ maxWidth: '28rem', margin: '1.5rem auto 0' }} onClick={() => lancer()} disabled={cles.length === 0 || occupe}>
              {occupe ? 'Tirage en cours…' : 'Lancer le tirage'}
            </button>
          )}
        </section>
      )}

      {phase === 'balayage' && (
        <section className="tdn-tirage-inner">
          {etape && <div className="tdn-tirage-etape">{etape}</div>}
          <h1 className="tdn-rev-titre">{titre}</h1>
          <div className="tdn-mur" ref={murRef}>
            {cles.map((c) => (
              <div key={c.id} data-id={c.id} className={`tdn-cle-tuile${allumee === c.id ? ' on' : ''}${dejaSorties.has(c.id) ? ' tiree' : ''}`}>
                {numeroCle(c.numero)}<small>{c.prenom}</small>
              </div>
            ))}
          </div>
        </section>
      )}

      {phase === 'tambour' && (
        <section className="tdn-tirage-inner">
          {etape && <div className="tdn-tirage-etape">{etape}</div>}
          <div className="tdn-sur tdn-sur-grand">Clé n°</div>
          <div className="tdn-tambour">{chiffres.map((c, i) => <span key={i}>{c}</span>)}</div>
          <p className="tdn-rev-sous" style={{ marginTop: '1.5rem' }}>{suspense}</p>
        </section>
      )}

      {phase === 'gagnant' && gagnant && (
        <section className="tdn-tirage-inner tdn-tirage-resultat" key={gagnant.cleId}>
          <div className="tdn-particules" aria-hidden="true">{Array.from({ length: 40 }).map((_, i) => <i key={i} style={{ left: `${(i * 41) % 100}%`, animationDelay: `${(i % 8) * .15}s` }} />)}</div>
          {etape && <div className="tdn-tirage-etape">{etape}</div>}
          <div className="tdn-sur tdn-sur-grand">{plusieurs ? 'Ce lot revient à' : 'Le Grand Trésor revient à'}</div>
          <div className="tdn-gagnant">
            <div className="tdn-gagnant-num">Clé n° {numeroCle(gagnant.numero)}</div>
            <div className="tdn-gagnant-nom">{gagnant.prenom}</div>
            {gagnant.famille && <div className="tdn-gagnant-famille">Famille {gagnant.famille}</div>}
          </div>
          {plusieurs ? (
            <>
              <p className="tdn-gagnant-lot">{lotUnitaire}</p>
              <div className="tdn-actions tdn-actions-col" style={{ width: '100%', maxWidth: '28rem', margin: '1.2rem auto 0' }}>
                {index < total - 1
                  ? <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={() => devoiler(index + 1, gagnants)}>Tirer le lot n° {index + 2}</button>
                  : <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={() => setPhase('final')}>Voir les {total} gagnants</button>}
              </div>
            </>
          ) : (
            <>
              <div className="tdn-lot" style={{ marginTop: '1rem' }}>{lot}</div>
              <p className="tdn-rev-sous">Félicitations, et merci d&apos;avoir joué avec nous !</p>
              <Link href="/tresors-de-noel/revelation" className="tdn-btn tdn-btn-ghost">Retour à l&apos;écran de révélation</Link>
            </>
          )}
        </section>
      )}

      {phase === 'final' && (
        <section className="tdn-tirage-inner tdn-tirage-resultat">
          <div className="tdn-particules" aria-hidden="true">{Array.from({ length: 40 }).map((_, i) => <i key={i} style={{ left: `${(i * 41) % 100}%`, animationDelay: `${(i % 8) * .15}s` }} />)}</div>
          <div className="tdn-sur tdn-sur-grand">Le Grand Trésor revient à</div>
          <div className="tdn-podium">
            {gagnants.map((g, i) => (
              <div className="tdn-gagnant" key={g.cleId}>
                <div className="tdn-gagnant-rang">Lot {i + 1}</div>
                <div className="tdn-gagnant-num">Clé n° {numeroCle(g.numero)}</div>
                <div className="tdn-gagnant-nom">{g.prenom}</div>
                {g.famille && <div className="tdn-gagnant-famille">Famille {g.famille}</div>}
              </div>
            ))}
          </div>
          <div className="tdn-lot tdn-lot-recap">{lot}</div>
          <p className="tdn-rev-sous">Félicitations, et merci d&apos;avoir joué avec nous !</p>
          <Link href="/tresors-de-noel/revelation" className="tdn-btn tdn-btn-ghost">Retour à l&apos;écran de révélation</Link>
        </section>
      )}
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/tresors/Tirage.tsx"
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
  /** Nombre de lots du grand trésor = nombre de clés tirées au sort. */
  grand_tresor_nombre: number;
  lieu_revelation: string;
  /** Première clé gagnante (ancien format, sert aussi de verrou du tirage). */
  tirage_cle_id: string | null;
  /** Toutes les clés gagnantes, dans l'ordre de sortie. */
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

/* ---------- Grand trésor : plusieurs lots identiques, un gagnant par lot ---------- */

/** Nombre de lots du grand trésor (1 au minimum, même si la colonne n'existe pas encore en base). */
export const nombreGrandTresor = (r: { grand_tresor_nombre?: number | null }) => Math.max(1, Math.floor(Number(r.grand_tresor_nombre)) || 1);

/** Montant affiché : « 3 × 100 € » s'il y a plusieurs lots, « 100 € » sinon (espaces insécables). */
export const montantGrandTresor = (r: { grand_tresor_nombre?: number | null; grand_tresor_montant: string }) => {
  const n = nombreGrandTresor(r);
  const unitaire = (r.grand_tresor_montant ?? '').replace(/ /g, '\u00a0');
  return n > 1 ? `${n}\u00a0×\u00a0${unitaire}` : unitaire;
};

/** Clés gagnantes enregistrées (nouveau format, sinon l'ancienne colonne à une seule clé). */
export const clesTirees = (r: { tirage_cle_ids?: string[] | null; tirage_cle_id?: string | null } | null | undefined): string[] =>
  r?.tirage_cle_ids?.length ? r.tirage_cle_ids : r?.tirage_cle_id ? [r.tirage_cle_id] : [];

const NOMBRES = ['zéro', 'une', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix'];
/** Petit nombre en toutes lettres, accordé au féminin (« une carte », « trois clés »). */
export const enLettres = (n: number) => NOMBRES[n] ?? String(n);
EOF_PN_FICHIER
echo "  ✓ src/lib/tresors/types.ts"
mkdir -p 'supabase'
cat > 'supabase/tresors_v2.sql' <<'EOF_PN_FICHIER'
-- =========================================================
-- Trésors de Noël v2
--   1. Grand trésor à plusieurs lots : 3 cartes cadeaux multi-enseignes de 100 €,
--      3 clés gagnantes différentes tirées au sort.
--   2. (Aucune table à modifier pour la règle « au moins un adulte pour inscrire
--      des enfants » : elle est appliquée par l'application.)
-- À exécuter une fois dans Supabase > SQL Editor (projet du CDF). Rejouable sans risque.
-- =========================================================

-- Nombre de lots du grand trésor = nombre de clés tirées au sort.
alter table public.tdn_reglages add column if not exists grand_tresor_nombre integer not null default 1;
-- Clés gagnantes du tirage, dans l'ordre de sortie (tirage_cle_id reste la première, et sert de verrou).
alter table public.tdn_reglages add column if not exists tirage_cle_ids uuid[] not null default '{}';

-- Reprise d'un éventuel tirage déjà enregistré à l'ancien format (une seule clé).
update public.tdn_reglages
   set tirage_cle_ids = array[tirage_cle_id]::uuid[]
 where tirage_cle_id is not null and tirage_cle_ids = '{}';

-- Nouveau grand trésor : 3 cartes cadeaux multi-enseignes de 100 €.
update public.tdn_reglages
   set grand_tresor_nombre  = 3,
       grand_tresor_montant = '100 €',
       grand_tresor_texte   = '3 cartes cadeaux multi-enseignes'
 where id = 1;

-- Lot « grand trésor » : c'est lui qui s'affiche quand une clé gagnante est saisie à la révélation.
update public.tdn_lots
   set nom = 'Carte cadeau multi-enseignes de 100 €', valeur = '100 €', stock = 3
 where grand = true;

insert into public.tdn_lots (nom, valeur, stock, grand, position)
select 'Carte cadeau multi-enseignes de 100 €', '100 €', 3, true, 0
 where not exists (select 1 from public.tdn_lots where grand = true);

-- Contrôle facultatif : comptes ayant déjà des enfants inscrits sans aucun adulte
-- (inscriptions antérieures à la nouvelle règle). Décommenter pour lister.
-- select c.prenom, c.nom, c.email, count(*) as enfants, bool_or(p.paye) as au_moins_un_paye
--   from public.tdn_comptes c
--   join public.tdn_participants p on p.compte_id = c.id
--  group by c.id, c.prenom, c.nom, c.email
-- having bool_and(p.categorie = 'enfant');
EOF_PN_FICHIER
echo "  ✓ supabase/tresors_v2.sql"

git add -A && git commit -m "Trésors de Noël : un adulte minimum pour inscrire des enfants, grand trésor en 3 cartes cadeaux de 100 €" && git push
vercel --prod
echo "Puis exécuter supabase/tresors_v2.sql dans Supabase (colonnes du tirage à 3 gagnants + réglages 3 × 100 €)."
