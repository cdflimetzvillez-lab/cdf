#!/usr/bin/env bash
# Installation du module « Le Père Noël te répond » dans le repo cdf.
# À exécuter à la racine du projet :  bash install-pere-noel.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Lance ce script à la racine du repo (package.json et src/app introuvables)."; exit 1
fi
echo "Installation du module Père Noël…"
cat > '.env.example' <<'EOF_PN_FICHIER'
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Stripe
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=

# Resend (envoi des billets par email)
RESEND_API_KEY=
RESEND_FROM_EMAIL="Comité des Fêtes Limetz-Villez <billetterie@limetz-villez.fr>"

# App
NEXT_PUBLIC_SITE_URL=http://localhost:3000

# Le Père Noël te répond (génération des vidéos)
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-6
ELEVENLABS_API_KEY=
ELEVENLABS_VOICE_ID=
HEYGEN_API_KEY=
CRON_SECRET=
EOF_PN_FICHIER
echo "  ✓ .env.example"
cat > 'INSTALLATION-PERE-NOEL.md' <<'EOF_PN_FICHIER'
# Le Père Noël te répond — installation

Fichiers à copier à la racine du repo (mêmes chemins). Fichiers modifiés :
src/components/MenuButton.tsx, src/components/NavAdmin.tsx, src/app/page.tsx,
src/app/evenements/[slug]/page.tsx, src/app/api/sumup/webhook/route.ts, .env.example.
Tout le reste est nouveau.

1. Supabase : exécuter supabase/pere_noel.sql dans l'éditeur SQL (tables pn_reglages, pn_commandes, vue pn_stats).
   Les médias utilisent le bucket public « medias » existant, dossier pere-noel/.
2. Vercel, variables d'environnement :
   ANTHROPIC_API_KEY, ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID (MDLAMJ0jxkpYkjXbmG4t),
   HEYGEN_API_KEY, CRON_SECRET (chaîne aléatoire). Redéployer.
3. Admin → 🎅 Père Noël vidéo → Réglages : charger l'image du Père Noël (portrait 9:16), vérifier la voix, enregistrer.
   Laisser « génération manuelle » et « relecture du script » cochés pour les premiers tests.
4. Admin → « + Commande de test » : le formulaire s'ouvre en mode test (sans paiement).
   Ouvrir la commande → Générer → relire le script → Valider → attendre 3 à 8 min → Vérifier.
   Sans crédits HeyGen, tout s'arrête proprement à l'étape vidéo avec le message d'erreur HeyGen.
5. Quand c'est bon : Réglages → « Commandes ouvertes » + activer le module (bouton en haut du tableau de bord).

Cron : vercel.json appelle /api/pere-noel/cron toutes les heures (sur le plan Hobby, Vercel le limite à une fois par jour).
En pratique les vidéos sont vérifiées à chaque ouverture de l'admin (toutes les 60 s tant que la page est ouverte)
et quand une famille ouvre son espace, donc le cron n'est qu'un filet de sécurité.
EOF_PN_FICHIER
echo "  ✓ INSTALLATION-PERE-NOEL.md"
mkdir -p 'src/app/admin/(protected)/pere-noel/[id]'
cat > 'src/app/admin/(protected)/pere-noel/[id]/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import { commandeParId } from '@/lib/pere-noel/db';
import { verifierVideo } from '@/lib/pere-noel/pipeline';
import { COUT_HEYGEN_USD_PAR_SEC, LIBELLE_GEN, LIBELLE_SAGESSE } from '@/lib/pere-noel/types';
import ActionsCommande from '@/components/pere-noel/ActionsCommande';
import FormScript from '@/components/pere-noel/FormScript';

export const maxDuration = 60;

export default async function AdminCommandePn({ params }: { params: Promise<{ id: string }> }) {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return null;
  const { id } = await params;
  let c = await commandeParId(id);
  if (!c) notFound();
  if (c.gen_statut === 'video') c = await verifierVideo(c.id);

  const ligne = (k: string, v?: string | number | null) => v ? <tr><th style={{ width: 180 }}>{k}</th><td style={{ whiteSpace: 'pre-line' }}>{v}</td></tr> : null;
  const etapes = [
    { l: 'Paiement', ok: c.statut === 'payee' },
    { l: 'Script (Claude)', ok: !!c.script },
    { l: 'Audio (ElevenLabs)', ok: !!c.audio_url },
    { l: 'Vidéo lancée (HeyGen)', ok: !!c.heygen_video_id || !!c.video_url },
    { l: 'Vidéo récupérée', ok: !!c.video_url },
    { l: 'Email envoyé', ok: c.email_envoye },
  ];
  const modifiable = ['a_faire', 'relecture', 'terminee', 'erreur'].includes(c.gen_statut) && c.statut === 'payee';

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>{c.enfant_prenom}{c.age ? `, ${c.age} ans` : ''}</h1>
          <p><code>{c.reference}</code> · {c.test ? 'commande de test' : euros(c.montant_centimes)} · {new Date(c.created_at).toLocaleString('fr-FR')}
            {' '}· <span className={`pill ${c.gen_statut === 'terminee' ? 'done' : c.gen_statut === 'erreur' ? 'off' : 'new'}`}>{LIBELLE_GEN[c.gen_statut]}</span></p>
        </div>
        <Link className="btn btn-w btn-sm" href="/admin/pere-noel">← Commandes</Link>
      </div>

      {c.erreur && c.gen_statut === 'erreur' && <div className="msg ko">Erreur : {c.erreur}</div>}
      {c.erreur && c.gen_statut !== 'erreur' && <div className="msg ko" style={{ background: '#FBEFD2' }}>Dernier incident (réessai automatique) : {c.erreur}</div>}

      <div className="panel">
        <h2>Actions</h2>
        <ActionsCommande c={c} />
      </div>

      <div className="row2">
        <div className="panel">
          <h2>Avancement</h2>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            {etapes.map((e) => <li key={e.l} style={{ padding: '.4rem 0', borderBottom: '1px solid #e2ddd6' }}><span className={`pill ${e.ok ? 'done' : 'off'}`}>{e.ok ? '✓' : '…'}</span> {e.l}</li>)}
          </ul>
          {c.heygen_video_id && <p style={{ marginTop: '.6rem', fontSize: '.8rem', color: '#6b6560' }}>HeyGen : <code>{c.heygen_video_id}</code></p>}
          {c.duree_sec && <p style={{ fontSize: '.85rem' }}>Durée : {c.duree_sec} s · coût HeyGen ≈ {(c.duree_sec * COUT_HEYGEN_USD_PAR_SEC).toFixed(2)} $</p>}
          <p style={{ marginTop: '.6rem' }}><Link href={`/pere-noel/ma-video/${c.token}`} target="_blank" className="btn btn-w btn-sm">↗ Espace famille</Link></p>
        </div>
        <div className="panel">
          <h2>Résultat</h2>
          {c.video_url ? (
            <>
              <video controls playsInline src={c.video_url} style={{ width: '100%', maxWidth: 260, borderRadius: 12, background: '#000', display: 'block' }} />
              <p style={{ marginTop: '.6rem' }}><a className="btn btn-w btn-sm" href={c.video_url} target="_blank" rel="noreferrer">Ouvrir le MP4</a></p>
            </>
          ) : c.audio_url ? (
            <><p style={{ color: '#6b6560', fontSize: '.9rem' }}>Audio prêt, vidéo en attente.</p><audio controls src={c.audio_url} style={{ width: '100%' }} /></>
          ) : <p style={{ color: '#6b6560' }}>Rien de généré pour l’instant.</p>}
        </div>
      </div>

      {c.script ? <FormScript c={c} modifiable={modifiable} /> : (
        <div className="panel"><h2>Script du Père Noël</h2><p style={{ color: '#6b6560' }}>Pas encore écrit. Cliquez sur « Générer » : Claude rédige le script à partir des réponses des parents{' '}
          (il apparaîtra ici pour relecture si l’option est activée dans les réglages).</p></div>
      )}

      <div className="panel">
        <h2>Réponses des parents</h2>
        <div className="tbl-wrap"><table className="tbl"><tbody>
          {ligne('Parent', `${c.parent_prenom} · ${c.email}`)}
          {ligne('Enfant', `${c.enfant_prenom}${c.prononciation ? ` (se prononce « ${c.prononciation} »)` : ''}${c.age ? `, ${c.age} ans` : ''}${c.genre ? `, ${c.genre}` : ''}`)}
          {ligne('Sagesse', LIBELLE_SAGESSE[c.sagesse])}
          {ligne('Lettre', c.lettre)}
          {ligne('Cadeaux demandés', c.cadeaux)}
          {ligne('Fierté', c.fierte)}
          {ligne('Doudou / passion', c.passion)}
          {ligne('Effort à encourager', c.effort)}
          {ligne('À saluer', c.salut)}
          {ligne(`Message secret (${c.ton_secret})`, c.secret)}
          {ligne('Paiement', c.statut === 'payee' ? `payée le ${c.paye_le ? new Date(c.paye_le).toLocaleString('fr-FR') : '—'}${c.transaction_code ? ` · ${c.transaction_code}` : ''}` : c.statut)}
        </tbody></table></div>
      </div>
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/admin/(protected)/pere-noel/[id]/page.tsx"
mkdir -p 'src/app/admin/(protected)/pere-noel'
cat > 'src/app/admin/(protected)/pere-noel/layout.tsx' <<'EOF_PN_FICHIER'
import NavPnAdmin from '@/components/pere-noel/NavPnAdmin';

export default function LayoutPn({ children }: { children: React.ReactNode }) {
  return (
    <>
      <NavPnAdmin />
      {children}
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/admin/(protected)/pere-noel/layout.tsx"
mkdir -p 'src/app/admin/(protected)/pere-noel'
cat > 'src/app/admin/(protected)/pere-noel/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import { lireReglagesPn, lireStatsPn, listerCommandes } from '@/lib/pere-noel/db';
import { creditsHeygen } from '@/lib/pere-noel/ia';
import { COUT_HEYGEN_USD_PAR_SEC, LIBELLE_GEN } from '@/lib/pere-noel/types';
import BasculeModulePn from '@/components/pere-noel/BasculeModulePn';
import BoutonVerifier from '@/components/pere-noel/BoutonVerifier';

export const maxDuration = 60;

const PILL: Record<string, string> = { a_faire: 'new', relecture: 'new', audio: 'on', video: 'on', terminee: 'done', erreur: 'off' };

export default async function AdminPereNoel() {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return null;
  const [r, s, commandes, credits] = await Promise.all([lireReglagesPn(), lireStatsPn(), listerCommandes(), creditsHeygen()]);
  const pret = !!r.image_url && !!(r.voice_id || process.env.ELEVENLABS_VOICE_ID) && !!process.env.HEYGEN_API_KEY && !!process.env.ELEVENLABS_API_KEY && !!process.env.ANTHROPIC_API_KEY;
  const coutUsd = (s.secondes_video * COUT_HEYGEN_USD_PAR_SEC).toFixed(2);

  return (
    <>
      <div className="adm-h">
        <div><h1>Le Père Noël te répond</h1><p>Vidéos personnalisées du Père Noël, générées à la commande.</p></div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          <Link className="btn btn-w btn-sm" href="/pere-noel" target="_blank">↗ Page publique</Link>
          <BoutonVerifier />
        </div>
      </div>

      <BasculeModulePn actif={r.module_actif} />

      {!pret && (
        <div className="msg ko">
          Configuration incomplète :
          {!r.image_url && ' image du Père Noël manquante ·'}
          {!(r.voice_id || process.env.ELEVENLABS_VOICE_ID) && ' voix ElevenLabs manquante ·'}
          {!process.env.ANTHROPIC_API_KEY && ' ANTHROPIC_API_KEY ·'}
          {!process.env.ELEVENLABS_API_KEY && ' ELEVENLABS_API_KEY ·'}
          {!process.env.HEYGEN_API_KEY && ' HEYGEN_API_KEY ·'}
          {' '}<Link href="/admin/pere-noel/reglages">ouvrir les réglages</Link>
        </div>
      )}

      <div className="kpi">
        <div><b>{s.commandes}</b><span>Commandes payées</span></div>
        <div><b>{euros(s.ca_centimes)}</b><span>Encaissé</span></div>
        <div><b>{s.a_generer + s.a_relire}</b><span>À traiter</span></div>
        <div><b>{s.en_cours}</b><span>En génération</span></div>
        <div><b>{s.livrees}</b><span>Livrées</span></div>
        <div><b>{s.en_erreur}</b><span>En erreur</span></div>
        <div><b>{credits ?? '—'}</b><span>Crédits HeyGen restants</span></div>
        <div><b>{coutUsd} $</b><span>Coût vidéo estimé</span></div>
      </div>

      <div className="panel">
        <h2>État</h2>
        <p>Commandes : <span className={`pill ${r.commandes_ouvertes ? 'on' : 'off'}`}>{r.commandes_ouvertes ? 'ouvertes' : 'fermées'}</span>
          {' '}· Génération : <span className={`pill ${r.generation_auto ? 'on' : 'off'}`}>{r.generation_auto ? 'automatique au paiement' : 'manuelle (bouton Générer)'}</span>
          {' '}· Relecture du script : <span className={`pill ${r.relecture_script ? 'on' : 'off'}`}>{r.relecture_script ? 'oui' : 'non'}</span>
          {' '}· Prix : <b>{euros(r.prix_centimes)}</b></p>
        <p style={{ marginTop: '.5rem', color: '#6b6560', fontSize: '.9rem' }}>
          Les vidéos en cours chez HeyGen sont vérifiées à chaque ouverture de cette page, quand la famille ouvre son espace, et par le bouton « Vérifier ». Une génération complète prend 3 à 8 minutes.
        </p>
      </div>

      <div className="panel">
        <h2>Commandes ({commandes.length})</h2>
        {commandes.length === 0 ? <p style={{ color: '#6b6560' }}>Aucune commande pour le moment. Faites une commande de test avec le bouton en haut.</p> : (
          <div className="tbl-wrap">
            <table className="tbl">
              <thead><tr><th>Réf.</th><th>Enfant</th><th>Parent</th><th>Paiement</th><th>Génération</th><th>Date</th><th></th></tr></thead>
              <tbody>
                {commandes.map((c) => (
                  <tr key={c.id}>
                    <td><code>{c.reference}</code>{c.test && <span className="pill new" style={{ marginLeft: 6 }}>test</span>}</td>
                    <td><b>{c.enfant_prenom}</b>{c.age ? `, ${c.age} ans` : ''}</td>
                    <td>{c.parent_prenom}<br /><small style={{ color: '#6b6560' }}>{c.email}</small></td>
                    <td><span className={`pill ${c.statut === 'payee' ? 'done' : c.statut === 'en_attente' ? 'new' : 'off'}`}>{c.statut === 'payee' ? (c.test ? 'test' : euros(c.montant_centimes)) : c.statut}</span></td>
                    <td><span className={`pill ${PILL[c.gen_statut] ?? 'off'}`}>{LIBELLE_GEN[c.gen_statut]}</span>{c.gen_statut === 'erreur' && <div style={{ fontSize: '.75rem', color: '#B8322E', maxWidth: 220 }}>{c.erreur?.slice(0, 120)}</div>}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>{new Date(c.created_at).toLocaleDateString('fr-FR')}</td>
                    <td><Link className="btn btn-w btn-sm" href={`/admin/pere-noel/${c.id}`}>Ouvrir</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/admin/(protected)/pere-noel/page.tsx"
mkdir -p 'src/app/admin/(protected)/pere-noel/reglages'
cat > 'src/app/admin/(protected)/pere-noel/reglages/page.tsx' <<'EOF_PN_FICHIER'
import { requireAdmin } from '@/lib/supabase/server';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import FormReglagesPn from '@/components/pere-noel/FormReglagesPn';

export default async function AdminReglagesPn() {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return null;
  const r = await lireReglagesPn();
  const cles = {
    anthropic: !!process.env.ANTHROPIC_API_KEY,
    elevenlabs: !!process.env.ELEVENLABS_API_KEY,
    heygen: !!process.env.HEYGEN_API_KEY,
    voixEnv: process.env.ELEVENLABS_VOICE_ID ?? '',
  };
  return (
    <>
      <div className="adm-h"><div><h1>Réglages du Père Noël</h1><p>Prix, ouverture, image, voix et consignes du script.</p></div></div>
      <FormReglagesPn r={r} cles={cles} />
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/admin/(protected)/pere-noel/reglages/page.tsx"
mkdir -p 'src/app/api/pere-noel/cron'
cat > 'src/app/api/pere-noel/cron/route.ts' <<'EOF_PN_FICHIER'
import { NextResponse, type NextRequest } from 'next/server';
import { traiterFile } from '@/lib/pere-noel/pipeline';

export const maxDuration = 60;
export const dynamic = 'force-dynamic';

/**
 * Passage périodique : vérifie les vidéos en cours chez HeyGen et, si la génération
 * automatique est activée, lance les commandes payées en attente.
 * Appelé par le cron Vercel (vercel.json) avec l'en-tête Authorization: Bearer CRON_SECRET,
 * ou à la main : /api/pere-noel/cron?secret=CRON_SECRET
 */
export async function GET(request: NextRequest) {
  const secret = process.env.CRON_SECRET;
  const auth = request.headers.get('authorization');
  const ok = !secret || auth === `Bearer ${secret}` || request.nextUrl.searchParams.get('secret') === secret;
  if (!ok) return NextResponse.json({ erreur: 'non autorisé' }, { status: 401 });
  try {
    const res = await traiterFile(5);
    return NextResponse.json({ ok: true, ...res });
  } catch (e: any) {
    console.error('[pere-noel cron]', e);
    return NextResponse.json({ erreur: String(e?.message ?? e) }, { status: 500 });
  }
}
EOF_PN_FICHIER
echo "  ✓ src/app/api/pere-noel/cron/route.ts"
mkdir -p 'src/app/api/sumup/webhook'
cat > 'src/app/api/sumup/webhook/route.ts' <<'EOF_PN_FICHIER'
import { NextResponse, type NextRequest } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { lireCheckout } from '@/lib/sumup';
import { envoyerBillet } from '@/app/reservation-actions';
import { synchroniserCommande } from '@/app/tresors-actions';
import { synchroniserCommandePn } from '@/app/pere-noel-actions';

/**
 * Webhook SumUp.
 * À déclarer dans le back-office SumUp :
 *   https://votre-domaine.fr/api/sumup/webhook
 *
 * On ne fait jamais confiance au corps de la requête : on relit
 * systématiquement l'état du checkout via l'API avant d'écrire.
 */
export async function POST(request: NextRequest) {
  // Filtre optionnel par jeton partagé dans l'URL : ?jeton=xxx
  const attendu = process.env.SUMUP_WEBHOOK_TOKEN;
  if (attendu && request.nextUrl.searchParams.get('jeton') !== attendu) {
    return NextResponse.json({ erreur: 'non autorisé' }, { status: 401 });
  }

  let corps: any;
  try {
    corps = await request.json();
  } catch {
    return NextResponse.json({ erreur: 'corps invalide' }, { status: 400 });
  }

  const checkoutId: string | undefined =
    corps?.id ?? corps?.checkout_id ?? corps?.payload?.id;

  if (!checkoutId) {
    return NextResponse.json({ erreur: 'checkout_id absent' }, { status: 400 });
  }

  try {
    const checkout = await lireCheckout(checkoutId);
    const db = createAdminClient();

    const correspondance: Record<string, string> = {
      PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente',
    };
    const statut = correspondance[checkout.status] ?? 'en_attente';

    const { data: avant } = await db
      .from('reservations')
      .select('id, statut')
      .eq('checkout_id', checkoutId)
      .maybeSingle();

    if (!avant) {
      // Trésors de Noël ? (référence TDN-…)
      const cmd = await synchroniserCommande(undefined, checkoutId);
      if (cmd) return NextResponse.json({ ok: true, module: 'tresors', statut: cmd.statut });
      // Père Noël ? (référence PN-…)
      const pn = await synchroniserCommandePn(undefined, checkoutId);
      if (pn) return NextResponse.json({ ok: true, module: 'pere-noel', statut: pn.statut });
      // Paiement inconnu : on répond 200 pour éviter que SumUp réessaie sans fin.
      console.warn('[webhook] réservation introuvable', checkoutId);
      return NextResponse.json({ ok: true, ignore: true });
    }

    if (avant.statut === statut) return NextResponse.json({ ok: true, inchange: true });

    const { data: apres } = await db
      .from('reservations')
      .update({
        statut,
        transaction_code: checkout.transaction_code
          ?? checkout.transactions?.[0]?.transaction_code
          ?? null,
        paye_le: statut === 'payee' ? new Date().toISOString() : null,
      })
      .eq('id', avant.id)
      .select('*, evenements(titre, slug, date_debut, lieu, heure_debut)')
      .single();

    if (statut === 'payee') await envoyerBillet(apres);

    return NextResponse.json({ ok: true, statut });
  } catch (e) {
    console.error('[webhook]', e);
    return NextResponse.json({ erreur: 'traitement impossible' }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({ service: 'webhook SumUp', actif: true });
}
EOF_PN_FICHIER
echo "  ✓ src/app/api/sumup/webhook/route.ts"
mkdir -p 'src/app/evenements/[slug]'
cat > 'src/app/evenements/[slug]/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { createClient } from '@/lib/supabase/server';
import { createStaticClient } from '@/lib/supabase/static';
import MenuButton from '@/components/MenuButton';
import Marquee from '@/components/Marquee';
import Footer from '@/components/Footer';
import FormulaireDemande from '@/components/FormulaireDemande';
import FormulaireReservation from '@/components/FormulaireReservation';
import GalerieEvenement from '@/components/GalerieEvenement';
import { jourMois, horaires, dateLongue, periode, texteSur } from '@/lib/format';
import type { Evenement, Creneau, InfoBloc, FaqItem, SiteSettings } from '@/lib/types';

export const revalidate = 60;

export async function generateStaticParams() {
  const supabase = createStaticClient();
  const { data } = await supabase.from('evenements').select('slug').eq('publie', true);
  return (data ?? []).map((e) => ({ slug: e.slug }));
}

export async function generateMetadata(
  { params }: { params: Promise<{ slug: string }> }
): Promise<Metadata> {
  const { slug } = await params;
  const supabase = await createClient();
  const { data } = await supabase.from('evenements')
    .select('titre, chapo, image_url').eq('slug', slug).maybeSingle();
  if (!data) return { title: 'Événement introuvable' };
  return {
    title: `${data.titre} — Comité des Fêtes de Limetz-Villez`,
    description: data.chapo ?? undefined,
    openGraph: {
      title: data.titre,
      description: data.chapo ?? undefined,
      images: [{
        url: data.image_url ?? '/og-image.png',
        width: 1200, height: 630, alt: data.titre,
      }],
    },
  };
}

export default async function PageEvenement(
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params;
  const supabase = await createClient();

  const { data: evt } = await supabase.from('evenements')
    .select('*').eq('slug', slug).eq('publie', true).maybeSingle();
  if (!evt) notFound();
  const e = evt as Evenement;
  const { data: tdn } = await supabase.from('tdn_reglages').select('module_actif').eq('id', 1).maybeSingle();
  const tdnActif = tdn?.module_actif !== false;
  const { data: pn } = await supabase.from('pn_reglages').select('module_actif').eq('id', 1).maybeSingle();
  const pnActif = pn?.module_actif === true;

  const [{ data: creneaux }, { data: infos }, { data: faq }, { data: documents }, { data: tarifs },
         { data: autres }, { data: settings }] = await Promise.all([
    supabase.from('creneaux').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('infos').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('faq').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('documents').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('tarifs').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('evenements').select('*').eq('publie', true).neq('id', e.id).order('position'),
    supabase.from('site_settings').select('*').eq('id', 1).single(),
  ]);

  const s = settings as SiteSettings;

  const { data: placesRestantes } = e.billetterie_active && e.places_max
    ? await supabase.rpc('places_restantes', { evt_id: e.id })
    : { data: null };

  const jm = jourMois(e.date_debut);
  const cr = (creneaux ?? []) as Creneau[];
  const tousDocs = (documents ?? []) as any[];
  const affiche = tousDocs.find((d) => d.est_affiche && d.type === 'image') ?? null;
  const autresDocs = tousDocs.filter((d) => d !== affiche);
  const grilleTarifs = (tarifs ?? []) as any[];
  const prixMini = grilleTarifs.length
    ? Math.min(...grilleTarifs.map((t) => t.prix_centimes))
    : e.prix_centimes;
  const plusieursTarifs = grilleTarifs.length > 1;
  const euros = (c: number) =>
    new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);


  return (
    <div style={{ ['--evt' as string]: e.couleur, ['--evt-dark' as string]: e.couleur_sombre }}>
      <MenuButton tresors={tdnActif} pereNoel={pnActif} />
      <Link className="crumb" href="/#evenements">← Tous les événements</Link>

      <header
        className={`ehero${e.image_url ? ' avec-image' : ''}`}
        style={e.image_url ? { backgroundImage: `url(${e.image_url})` } : undefined}
      >
        <div className="ehero-inner">
          <span className="badge-num">{periode(e.date_debut, e.date_fin)}</span>
          <h1>{e.titre}</h1>
          {e.chapo && <p className="ehero-lead">{e.chapo}</p>}

          <div className="keys">
            <div className="key">
              <div className="k">Date</div>
              <div className="v">{jm.jour} {jm.date}</div>
            </div>
            <div className="key">
              <div className="k">Horaires</div>
              <div className="v">{horaires(e.heure_debut, e.heure_fin)}</div>
            </div>
            <div className="key">
              <div className="k">Lieu</div>
              <div className="v">{e.lieu}</div>
            </div>
            <div className="key">
              <div className="k">Tarif</div>
              <div className="v">
                {e.billetterie_active && prixMini > 0 ? (
                  <>
                    {plusieursTarifs && <small>À partir de</small>}
                    {euros(prixMini)}
                  </>
                ) : e.tarif}
              </div>
            </div>
          </div>

          <div className="ehero-cta">
            {cr.length > 0 && <a className="btn btn-y" href="#programme">Voir le programme</a>}
            <a className="btn btn-w" href={e.billetterie_active ? '#reserver' : '#participer'}>
              {e.billetterie_active ? e.libelle_reservation : 'Participer'}
            </a>
            {infos && infos.length > 0 && <a className="btn btn-k" href="#infos">Y aller</a>}
          </div>
        </div>
      </header>

      {cr.length > 0 && (
        <Marquee items={cr.map((c) => `${c.heure} ${c.titre}`)} />
      )}

      {cr.length > 0 && (
        <section id="programme">
          <div className="wrap">
            <div className="head">
              <h2>Le déroulé</h2>
              {e.description && <p>{e.description}</p>}
            </div>
            <div className={affiche ? 'prog-avec-affiche' : ''}>
            {affiche && (
              <a className="prog-affiche" href={affiche.url} target="_blank" rel="noreferrer">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={affiche.url} alt={affiche.titre ?? "Affiche de l'événement"} />
                <span>Voir en grand</span>
              </a>
            )}
            <div className="timeline">
              {cr.map((c) => (
                <div className="slot" key={c.id}>
                  <div className="t">{c.heure}</div>
                  <div className="h">{c.titre}</div>
                  {c.description && <p>{c.description}</p>}
                  {c.scene && <span className="stage">{c.scene}</span>}
                </div>
              ))}
            </div>
            </div>
          </div>
        </section>
      )}

      {infos && infos.length > 0 && (
        <section className="info" id="infos">
          <div className="wrap">
            <div className="head">
              <h2>Infos pratiques</h2>
              <p>Tout ce qu&apos;il faut savoir avant de venir.</p>
            </div>
            <div className="info-grid">
              {(infos as InfoBloc[]).map((b) => (
                <div className="icard" key={b.id}>
                  <h3>{b.titre}</h3>
                  <ul>{b.lignes.map((l, i) => <li key={i}>{l}</li>)}</ul>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}

      {e.billetterie_active ? (
        <section className="take" id="reserver">
          <div className="wrap take-grid">
            <div>
              <h2>Réservez votre place</h2>
              <p style={{ marginTop: '1rem', fontWeight: 600, maxWidth: '44ch', lineHeight: 1.6 }}>
                Paiement en ligne sécurisé. Votre billet vous est envoyé par email
                dès le règlement effectué.
              </p>
            </div>
            <FormulaireReservation
              evenementId={e.id}
              tarifs={grilleTarifs}
              prixCentimes={e.prix_centimes}
              placesMax={e.places_par_reservation}
              placesRestantes={placesRestantes as number | null}
              cloture={e.cloture_reservations}
            />
          </div>
        </section>
      ) : (
        <section className="take" id="participer">
          <div className="wrap take-grid">
            <div>
              <h2>Participer à l&apos;organisation</h2>
              <p style={{ marginTop: '1rem', fontWeight: 600, maxWidth: '44ch', lineHeight: 1.6 }}>
                Exposant, musicien, ou simple coup de main pour le montage : dites-nous
                ce que vous proposez, le comité vous répond.
              </p>
            </div>
            <FormulaireDemande evenementId={e.id} />
          </div>
        </section>
      )}

      {autresDocs.length > 0 && (
        <section id="documents">
          <div className="wrap">
            <div className="head">
              <h2>Affiches et documents</h2>
              <p>Cliquez pour agrandir.</p>
            </div>
            <GalerieEvenement documents={autresDocs as any} />
          </div>
        </section>
      )}

      {faq && faq.length > 0 && (
        <section>
          <div className="wrap">
            <div className="head"><h2>Questions fréquentes</h2></div>
            <div className="faq">
              {(faq as FaqItem[]).map((f, i) => (
                <details key={f.id} open={i === 0}>
                  <summary>{f.question}</summary>
                  <p>{f.reponse}</p>
                </details>
              ))}
            </div>
          </div>
        </section>
      )}

      {autres && autres.length > 0 && (
        <section style={{ borderTop: '4px solid var(--noir)' }}>
          <div className="wrap">
            <div className="head"><h2>Les autres rendez-vous</h2></div>
            <div className="grid">
              {(autres as Evenement[]).map((o) => {
                const fg = texteSur(o.couleur);
                return (
                  <Link
                    key={o.id}
                    href={`/evenements/${o.slug}`}
                    className={`poster${fg === '#FFF8EC' ? ' dark' : ''}`}
                    style={{ background: o.couleur, color: fg, minHeight: 200 }}
                  >
                    <div>
                      <div className="when">{dateLongue(o.date_debut)}</div>
                      <h3>{o.titre}</h3>
                    </div>
                    <span className="price">{o.tarif}</span>
                  </Link>
                );
              })}
            </div>
          </div>
        </section>
      )}

      <Footer settings={s} evenements={(autres ?? []) as Evenement[]} />
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/evenements/[slug]/page.tsx"
mkdir -p 'src/app'
cat > 'src/app/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import MenuButton from '@/components/MenuButton';
import RetourHaut from '@/components/RetourHaut';
import Marquee from '@/components/Marquee';
import Footer from '@/components/Footer';
import RoueRentree from '@/components/roue/RoueRentree';
import BandeauPartenaires from '@/components/BandeauPartenaires';
import { configRoue, getWheelConfig, roueVisible } from '@/lib/roue/db';
import { dateCourte, dateLongue, horaires, periode, texteSur } from '@/lib/format';
import type { Partenaire, SiteSettings, Stat, Evenement } from '@/lib/types';

export const revalidate = 60;

export default async function Home() {
  const supabase = await createClient();

  const [{ data: settings }, { data: stats }, { data: evenements }, wheelConfig, { data: partenaires }, { data: tdn }, { data: pn }] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(),
    supabase.from('stats').select('*').order('position'),
    supabase.from('evenements').select('*').eq('publie', true).order('position'),
    getWheelConfig(),
    supabase.from('partenaires').select('*').eq('actif', true).order('position'),
    supabase.from('tdn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
    supabase.from('pn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
  ]);
  // Module événementiel : rendu côté serveur uniquement si actif et dans la période.
  const showWheel = roueVisible(wheelConfig);

  const s = settings as SiteSettings;
  const evts = (evenements ?? []) as Evenement[];

  return (
    <>
      <MenuButton tresors={tdn?.module_actif !== false} pereNoel={pn?.module_actif === true} />
      <RetourHaut />

      <header className="hero" style={{ ['--evt' as string]: s.hero_couleur }}>
        <div className="hero-inner">
          <div className="logo-badge">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              className="hero-logo"
              src={s.logo_url || '/logo-cdf.png'}
              alt="Comité des Fêtes de Limetz-Villez"
            />
          </div>
          <div style={{ marginBottom: '2.4rem' }}>
            <span className="kicker mono">{s.hero_kicker}</span>
          </div>
          <h1>
            {s.hero_titre_1} <span className="jaune">{s.hero_titre_accent}</span>
            <br />
            <span className="cyan">{s.hero_titre_2}</span>
          </h1>
          <p className="hero-tag">{s.hero_texte}</p>
          <div className="hero-cta">
            <a className="btn btn-y" href="#evenements">Voir le programme</a>
            <a className="btn btn-w" href="#benevoles">Devenir bénévole</a>
          </div>
        </div>

        <a className="scroll-hint" href="#evenements">
          <span>Faire défiler</span>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3"
               strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M6 9l6 6 6-6" />
          </svg>
        </a>
      </header>

      <Marquee items={evts.map((e) => `${dateCourte(e.date_debut)} · ${e.titre}`)} />

      {showWheel && <RoueRentree config={configRoue(wheelConfig)} />}

      <section id="evenements">
        <div className="wrap">
          <div className="head">
            <h2>Le programme</h2>
            <p>Nos rendez-vous de l&apos;année. Cliquez pour les horaires, le lieu et les inscriptions.</p>
          </div>
          <div className="grid">
            {evts.map((e, i) => {
              const fg = texteSur(e.couleur);
              return (
                <Link
                  key={e.id}
                  href={`/evenements/${e.slug}`}
                  className={`poster${fg === '#FFF8EC' ? ' dark' : ''}`}
                  style={{ background: e.couleur, color: fg }}
                >
                  <span className="num">{String(i + 1).padStart(2, '0')}</span>
                  <div>
                    <div className="when">
                      {periode(e.date_debut, e.date_fin)}{horaires(e.heure_debut, e.heure_fin) && ` · ${horaires(e.heure_debut, e.heure_fin)}`}
                    </div>
                    <h3>{e.titre}</h3>
                    <p>{e.chapo}</p>
                  </div>
                  <span className="price">{e.tarif}</span>
                </Link>
              );
            })}
          </div>
        </div>
        <BandeauPartenaires partenaires={(partenaires ?? []) as Partenaire[]} />
      </section>

      <section className="about" id="association">
        <div className="wrap">
          <div className="head"><h2>{s.asso_titre}</h2></div>
          <div className="about-grid">
            <div>
              {s.asso_texte.split('\n\n').map((p, i) => <p key={i}>{p}</p>)}
            </div>
            <div className="stats">
              {(stats as Stat[] ?? []).map((st) => (
                <div className="stat" key={st.id}>
                  <b>{st.valeur}</b>
                  <span>{st.libelle}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="join" id="benevoles">
        <div className="mono" style={{ marginBottom: '1rem' }}>On a besoin de bras</div>
        <h2>{s.benevoles_titre}</h2>
        <p>{s.benevoles_texte}</p>
        <a className="btn btn-y" href={`mailto:${s.email_contact}`}>Nous contacter</a>
      </section>

      <Footer settings={s} evenements={evts} />
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/page.tsx"
mkdir -p 'src/app'
cat > 'src/app/pere-noel-actions.ts' <<'EOF_PN_FICHIER'
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
  const { isAdmin } = await requireAdmin();
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

  const db = createAdminClient();
  const reference = referencePn();
  const montant = modeTest ? 0 : r.prix_centimes;
  const { data: cmd, error } = await db.from('pn_commandes').insert({
    reference, test: modeTest,
    parent_prenom: txt(fd, 'parent_prenom', 60) ?? '', email,
    enfant_prenom: enfant, prononciation: txt(fd, 'prononciation', 60),
    age: Number.isFinite(age) && age > 0 && age < 18 ? age : null, genre, sagesse,
    lettre, cadeaux: txt(fd, 'cadeaux', 300), fierte: txt(fd, 'fierte', 300), passion: txt(fd, 'passion', 300),
    effort: txt(fd, 'effort', 200), salut: txt(fd, 'salut', 120), secret: txt(fd, 'secret', 500), ton_secret: ton,
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
      description: `${reference} · Vidéo du Père Noël pour ${enfant}`,
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
  const { isAdmin } = await requireAdmin();
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

export async function supprimerCommande(id: string) {
  await admin();
  await createAdminClient().from('pn_commandes').delete().eq('id', id);
  chemins();
  redirect('/admin/pere-noel');
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel-actions.ts"
mkdir -p 'src/app/pere-noel/commander'
cat > 'src/app/pere-noel/commander/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import FormCommande from '@/components/pere-noel/FormCommande';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { requireAdmin } from '@/lib/supabase/server';

export default async function PageCommander({ searchParams }: { searchParams: Promise<{ test?: string }> }) {
  const [r, { isAdmin }, sp] = await Promise.all([lireReglagesPn(), requireAdmin(), searchParams]);
  const test = sp.test === '1' && isAdmin;
  if (!r.commandes_ouvertes && !test) {
    return (
      <main className="pn-page pn-centre">
        <h1 className="pn-titre">Les commandes ne sont pas ouvertes</h1>
        <p className="pn-l clair">Revenez bientôt, le Père Noël prépare son atelier.</p>
        <Link href="/pere-noel" className="pn-btn ghost">Retour</Link>
      </main>
    );
  }
  return (
    <main className="pn-page">
      <FormCommande prix={r.prix_centimes} test={test} />
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/commander/page.tsx"
mkdir -p 'src/app/pere-noel/commander/retour'
cat > 'src/app/pere-noel/commander/retour/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { synchroniserCommandePn } from '@/app/pere-noel-actions';
import { euros } from '@/lib/sumup';

export const maxDuration = 60;

export default async function PageRetour({ searchParams }: { searchParams: Promise<{ ref?: string }> }) {
  const { ref } = await searchParams;
  const cmd = ref ? await synchroniserCommandePn(ref) : null;

  if (!cmd) {
    return <main className="pn-page pn-centre"><h1 className="pn-titre">Commande introuvable</h1><Link href="/pere-noel" className="pn-btn ghost">Retour</Link></main>;
  }
  if (cmd.statut === 'payee') {
    return (
      <main className="pn-page pn-centre">
        <div className="pn-ok">✓</div>
        <h1 className="pn-titre">La lettre de {cmd.enfant_prenom} est partie pour le Pôle Nord</h1>
        <p className="pn-l clair">Le Père Noël enregistre sa réponse. Vous recevrez un email dès que la vidéo est prête.</p>
        <div className="pn-cardn" style={{ textAlign: 'left' }}><b>Votre espace personnel</b><small>Vidéo, téléchargement, lettre écrite et certificat vous y attendent. Le lien vous a aussi été envoyé par email.</small></div>
        <Link href={`/pere-noel/ma-video/${cmd.token}`} className="pn-btn or">Ouvrir mon espace</Link>
        <p className="pn-mini pn-muted" style={{ marginTop: 14 }}>{cmd.test ? 'Commande de test' : euros(cmd.montant_centimes)} · réf. {cmd.reference}</p>
        <div className="pn-avis" style={{ textAlign: 'left' }}><b>Un conseil :</b> ne montrez pas la vidéo à {cmd.enfant_prenom} tout de suite. Le soir, dans le noir, sur la télé, l&apos;effet est décuplé.</div>
      </main>
    );
  }
  if (cmd.statut === 'en_attente') {
    return (
      <main className="pn-page pn-centre">
        <h1 className="pn-titre">Paiement en cours de vérification</h1>
        <p className="pn-l clair">Cela peut prendre quelques secondes.</p>
        <Link href={`/pere-noel/commander/retour?ref=${cmd.reference}`} className="pn-btn or">Actualiser</Link>
      </main>
    );
  }
  return (
    <main className="pn-page pn-centre">
      <h1 className="pn-titre">Paiement non abouti</h1>
      <p className="pn-l clair">Le paiement a échoué ou a expiré. Rien n&apos;a été débité, vous pouvez recommencer.</p>
      <Link href="/pere-noel/commander" className="pn-btn or">Recommencer</Link>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/commander/retour/page.tsx"
mkdir -p 'src/app/pere-noel'
cat > 'src/app/pere-noel/layout.tsx' <<'EOF_PN_FICHIER'
import type { Metadata } from 'next';
import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { requireAdmin } from '@/lib/supabase/server';
import './pere-noel.css';

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  const r = await lireReglagesPn();
  return { title: `${r.titre} · Comité des Fêtes`, description: r.accroche };
}

export default async function PereNoelLayout({ children }: { children: React.ReactNode }) {
  const r = await lireReglagesPn();
  if (!r.module_actif) {
    const { isAdmin } = await requireAdmin();
    if (!isAdmin) {
      return (
        <div className="pn">
          <main className="pn-page pn-centre" style={{ paddingTop: '20vh' }}>
            <h1 className="pn-titre">{r.titre}</h1>
            <p className="pn-l clair">Ce service n&apos;est pas disponible pour le moment. Revenez bientôt !</p>
            <Link href="/" className="pn-btn ghost">Retour au site</Link>
          </main>
        </div>
      );
    }
  }
  return (
    <div className="pn">
      <div className="pn-head">
        <Link href="/pere-noel" className="logo">{r.titre}</Link>
        <Link href="/" className="cdf">Une action du Comité des Fêtes</Link>
      </div>
      {children}
      <div className="pn-foot">Une action du Comité des Fêtes. Les bénéfices financent les événements de l&apos;année. Aucune donnée d&apos;enfant n&apos;est publiée.</div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/layout.tsx"
mkdir -p 'src/app/pere-noel/ma-video/[token]/certificat'
cat > 'src/app/pere-noel/ma-video/[token]/certificat/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

export default async function PageCertificat({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);
  const annee = d.getFullYear();
  const mention = c.certificat_mention || `pour son année ${annee}, remarquée depuis le ciel pour sa gentillesse et son courage.`;
  const fem = c.genre === 'fille';

  return (
    <div className="pn-doc">
      <div className="pn-doc-feuille">
        <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
        <h1>Certificat d&apos;enfant sage</h1>
        <p style={{ textAlign: 'center', margin: 0 }}>décerné à</p>
        <div className="prenom">{c.enfant_prenom}</div>
        <p style={{ textAlign: 'center' }}>{mention}</p>
        <p style={{ textAlign: 'center', fontSize: 15, color: '#6B5E4C' }}>Le Père Noël atteste que {c.enfant_prenom} est inscrit{fem ? 'e' : ''} sur la liste des enfants sages de l&apos;année {annee}.</p>
        <div className="bas">
          <div style={{ fontSize: 14, color: '#6B5E4C' }}>Fait au Pôle Nord,<br />le {d.getDate()} {MOIS[d.getMonth()]} {annee}</div>
          <div className="sceau">Bureau<br />du Père Noël<br />★</div>
        </div>
      </div>
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/ma-video/[token]/certificat/page.tsx"
mkdir -p 'src/app/pere-noel/ma-video/[token]/lettre'
cat > 'src/app/pere-noel/ma-video/[token]/lettre/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

export default async function PageLettre({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);

  return (
    <div className="pn-doc">
      <div className="pn-doc-feuille">
        <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord · le {d.getDate()} {MOIS[d.getMonth()]} {d.getFullYear()}</div>
        <p className="lettre" style={{ marginTop: 22 }}>{c.lettre_reponse}</p>
        <div className="bas">
          <div />
          <div className="sceau">Bureau<br />du Père Noël<br />★</div>
        </div>
      </div>
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/ma-video/[token]/lettre/page.tsx"
mkdir -p 'src/app/pere-noel/ma-video/[token]'
cat > 'src/app/pere-noel/ma-video/[token]/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import { rafraichirDepuisEspace } from '@/app/pere-noel-actions';

export const maxDuration = 60;

export default async function PageMaVideo({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  let c = await commandeParToken(token);
  if (!c) notFound();
  if (c.gen_statut === 'video') { await rafraichirDepuisEspace(c.id); c = (await commandeParToken(token))!; }

  const prete = c.gen_statut === 'terminee' && c.video_url;
  const nomFichier = `Pere-Noel-${c.enfant_prenom.replace(/[^a-zA-Z0-9À-ÿ]/g, '')}.mp4`;
  const urlTelechargement = c.video_url ? `${c.video_url}${c.video_url.includes('?') ? '&' : '?'}download=${encodeURIComponent(nomFichier)}` : '#';
  const docsPrets = !!c.lettre_reponse;

  return (
    <main className="pn-page">
      <h1 className="pn-titre">La réponse du Père Noël à {c.enfant_prenom}</h1>

      {c.statut !== 'payee' && (
        <div className="pn-cardn"><b>Paiement non confirmé</b><small>Cette commande n&apos;a pas encore été réglée. Si vous venez de payer, patientez quelques instants puis actualisez.</small></div>
      )}

      {prete ? (
        <>
          <div className="pn-video"><video controls playsInline preload="metadata" src={c.video_url!} /></div>
          <a className="pn-btn or" href={urlTelechargement} download={nomFichier}>Télécharger la vidéo (MP4)</a>
          <p className="pn-mini pn-muted pn-centre" style={{ marginTop: 8 }}>Pensez à la télécharger et à la sauvegarder : elle reste disponible ici jusqu&apos;au 31 janvier.</p>
        </>
      ) : c.statut === 'payee' && (
        <div className="pn-cardn">
          <b>Le Père Noël prépare sa réponse…</b>
          <small>Vous recevrez un email dès que la vidéo est prête. Vous pouvez aussi revenir sur cette page plus tard.</small>
          <ul className="pn-etapes" style={{ marginTop: 10 }}>
            <li className="ok"><span>✓</span><div>Lettre reçue au Pôle Nord</div></li>
            <li className={c.script ? 'ok' : 'now'}><span>{c.script ? '✓' : '…'}</span><div>Le Père Noël lit la lettre et prépare sa réponse</div></li>
            <li className={c.audio_url ? 'ok' : c.script ? 'now' : ''}><span>{c.audio_url ? '✓' : '…'}</span><div>Il enregistre sa voix</div></li>
            <li className={c.gen_statut === 'video' ? 'now' : ''}><span>…</span><div>Les lutins montent la vidéo</div></li>
          </ul>
        </div>
      )}

      <div className="pn-carte" style={{ marginTop: 18 }}>
        <h2>À imprimer</h2>
        <p className="pn-l">{docsPrets ? 'La lettre écrite du Père Noël et le certificat d\u2019enfant sage sont prêts.' : 'La lettre écrite et le certificat seront disponibles dès que le Père Noël aura préparé sa réponse.'}</p>
        <div className="pn-row">
          <Link className={`pn-btn sec${docsPrets ? '' : ' disabled'}`} aria-disabled={!docsPrets} href={docsPrets ? `/pere-noel/ma-video/${c.token}/lettre` : '#'}>La lettre</Link>
          <Link className={`pn-btn sec${docsPrets ? '' : ' disabled'}`} aria-disabled={!docsPrets} href={docsPrets ? `/pere-noel/ma-video/${c.token}/certificat` : '#'}>Le certificat</Link>
        </div>
      </div>

      <div className="pn-cardn"><b>Quelque chose ne va pas ?</b><small>Prénom mal prononcé, détail inexact : répondez à l&apos;email de confirmation en indiquant la référence {c.reference}, nous refaisons la vidéo.</small></div>
      <div className="pn-avis"><b>Un conseil :</b> ne montrez pas la vidéo tout de suite. Le soir, dans le noir, sur la télé du salon, l&apos;effet est décuplé.</div>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/ma-video/[token]/page.tsx"
mkdir -p 'src/app/pere-noel'
cat > 'src/app/pere-noel/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { euros } from '@/lib/sumup';

export default async function PageAccueilPn() {
  const r = await lireReglagesPn();
  const flocons = [12, 30, 48, 66, 84];

  return (
    <main className="pn-page">
      <div className="pn-hero">
        {r.image_url
          // eslint-disable-next-line @next/next/no-img-element
          ? <img src={r.image_url} alt="Le Père Noël dans son atelier" />
          : <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#9FB0D6' }}>Image du Père Noël à définir</div>}
        {flocons.map((x, i) => <i key={x} className="pn-flocon" style={{ left: `${x}%`, top: `${(i * 17) % 40}%`, animationDuration: `${6 + i}s`, animationDelay: `${i * .7}s` }} />)}
        <div className="sous">« Bonjour Léa, j&apos;ai bien reçu ta lettre… »</div>
      </div>

      <h1 className="pn-titre">{r.accroche}</h1>
      <p className="pn-l clair">
        Pas un message tout fait avec un prénom collé dessus : une vraie réponse à ce que votre enfant a écrit.
        Sa lettre, son doudou, ses fiertés de l&apos;année, tout y est. À télécharger et à garder pour toujours.
      </p>

      <div className="pn-cardn"><b>{euros(r.prix_centimes)}</b> la vidéo personnalisée<small>Livrée {r.delai_texte}. Lettre écrite du Père Noël et certificat d&apos;enfant sage inclus.</small></div>

      {r.commandes_ouvertes
        ? <Link href="/pere-noel/commander" className="pn-btn or">Écrire au Père Noël</Link>
        : <p className="pn-cardn pn-centre">Les commandes ouvriront bientôt.</p>}

      <div className="pn-avis"><b>Comment ça marche ?</b> Vous remplissez la lettre avec votre enfant (5 minutes). Le Père Noël enregistre sa réponse. Vous recevez un lien par email avec la vidéo à télécharger.</div>

      <ul className="pn-etapes" style={{ marginTop: 18 }}>
        <li className="ok"><span>1</span><div>Vous racontez : prénom, sa lettre, ses fiertés, un petit secret que seul le Père Noël pouvait connaître.</div></li>
        <li className="ok"><span>2</span><div>Le Père Noël répond, en vidéo, avec ses mots à lui et le prénom de votre enfant.</div></li>
        <li className="ok"><span>3</span><div>Vous téléchargez la vidéo, imprimez la lettre et le certificat. Magie garantie le soir de Noël.</div></li>
      </ul>

      <div className="pn-faq" style={{ marginTop: 22 }}>
        <details><summary>Le Père Noël dit vraiment le prénom ?</summary><p>Oui. Vous pouvez même indiquer comment il se prononce pour éviter toute erreur.</p></details>
        <details><summary>Combien de temps dure la vidéo ?</summary><p>Environ une minute quinze, en format vertical plein écran, idéale sur un téléphone ou la télé du salon.</p></details>
        <details><summary>Et si quelque chose ne va pas ?</summary><p>Un détail inexact, un prénom mal prononcé : écrivez-nous depuis votre espace, nous refaisons la vidéo.</p></details>
        <details><summary>Où va l&apos;argent ?</summary><p>C&apos;est une action du Comité des Fêtes : les bénéfices financent les événements de l&apos;année.</p></details>
      </div>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/page.tsx"
mkdir -p 'src/app/pere-noel'
cat > 'src/app/pere-noel/pere-noel.css' <<'EOF_PN_FICHIER'
/* =========================================================
   LE PÈRE NOËL TE RÉPOND — feuille dédiée, préfixe .pn
   Palette : nuit, rouge, or, papier. Polices système.
   ========================================================= */
.pn{
  --pn-nuit:#1B2A4A; --pn-nuit2:#122040; --pn-rouge:#B8322E; --pn-rouge2:#8F2420;
  --pn-or:#D4A64A; --pn-papier:#F7EFDD; --pn-papier2:#EFE3C6; --pn-encre:#2A2116;
  --pn-encre2:#6B5E4C; --pn-neige:#fff; --pn-vert:#2F6B4A;
  min-height:100vh; background:var(--pn-nuit); color:var(--pn-papier);
  font-family:"Segoe UI",Roboto,Helvetica,Arial,sans-serif; line-height:1.5; -webkit-font-smoothing:antialiased;
}
.pn *{box-sizing:border-box}
.pn :where(h1,h2,h3){font-family:Georgia,"Times New Roman",serif;font-weight:normal;text-transform:none;letter-spacing:.01em;line-height:1.15;}
.pn :where(section,footer){padding:0;background:transparent;color:inherit;display:block;}
.pn a{color:inherit}
.pn button{font-family:inherit}

.pn-head{display:flex;justify-content:space-between;align-items:center;padding:14px 18px;font-size:13px;max-width:560px;margin:0 auto;}
.pn-head .logo{font-family:Georgia,serif;font-size:16px;color:var(--pn-or);text-decoration:none;}
.pn-head .cdf{opacity:.75;font-size:11px;text-decoration:none}
.pn-page{max-width:560px;margin:0 auto;padding:12px 18px 60px;}
.pn-carte{background:var(--pn-papier);color:var(--pn-encre);border-radius:22px;padding:22px 20px;margin:14px 0;}
.pn-carte h2{font-size:22px;margin:0 0 6px}
.pn-l{color:var(--pn-encre2);font-size:14px;margin:0 0 12px}
.pn-l.clair{color:#C9D3EC}
.pn-titre{font-size:30px;margin:14px 0 8px}
.pn-mini{font-size:12px}.pn-muted{color:#9FB0D6}
.pn-centre{text-align:center}

.pn-btn{display:block;width:100%;text-align:center;background:var(--pn-rouge);color:#fff;border:0;border-radius:12px;padding:14px 16px;font-size:16px;font-family:Georgia,serif;margin-top:14px;text-decoration:none;cursor:pointer}
.pn-btn:disabled{opacity:.5;cursor:not-allowed}
.pn-btn.sec{background:transparent;color:var(--pn-rouge);border:1.5px solid var(--pn-rouge)}
.pn .pn-carte .pn-btn.sec{color:var(--pn-rouge)}
.pn-btn.or{background:var(--pn-or);color:var(--pn-encre)}
.pn-btn.vert{background:var(--pn-vert)}
.pn-btn.ghost{background:transparent;color:var(--pn-papier);border:1.5px solid rgba(255,255,255,.35)}
.pn-lien{background:none;border:0;color:var(--pn-encre2);text-decoration:underline;font-size:13px;margin-top:10px;cursor:pointer;display:block;width:100%;text-align:center}

.pn-champ{margin-top:12px}
.pn-champ label{display:block;font-size:13px;color:var(--pn-encre2);margin:0 0 5px}
.pn-champ input,.pn-champ textarea,.pn-champ select{width:100%;border:1.5px solid #D6C9A8;background:#fff;border-radius:10px;padding:11px 12px;font-size:16px;font-family:inherit;color:var(--pn-encre)}
.pn-champ textarea{min-height:120px;resize:vertical}
.pn-row{display:flex;gap:10px}.pn-row>*{flex:1}

.pn-steps{display:flex;gap:6px;margin:6px 0 4px}
.pn-steps i{flex:1;height:5px;border-radius:3px;background:rgba(255,255,255,.2)}
.pn-steps i.on{background:var(--pn-or)}
.pn-stepname{font-size:12px;color:#9FB0D6;margin-bottom:6px}

.pn-opts{display:flex;gap:6px;margin-top:6px}
.pn-opts label{flex:1;text-align:center;border:1.5px solid #D6C9A8;background:#fff;border-radius:10px;padding:10px 4px;font-size:12px;cursor:pointer;line-height:1.25;color:var(--pn-encre)}
.pn-opts label b{display:block;font-size:22px;font-family:Georgia,serif;font-weight:normal}
.pn-opts label.on{border-color:var(--pn-rouge);background:#FBE9E5;color:var(--pn-rouge2)}
.pn-opts input{position:absolute;opacity:0;width:0;height:0}

.pn-chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:6px}
.pn-chips label{border:1.5px solid #D6C9A8;background:#fff;border-radius:20px;padding:7px 12px;font-size:13px;cursor:pointer;color:var(--pn-encre)}
.pn-chips label.on{background:var(--pn-nuit);color:var(--pn-papier);border-color:var(--pn-nuit)}
.pn-chips input{position:absolute;opacity:0;width:0;height:0}

.pn-parch{background:#fff;border:1px solid #E2D6B6;border-radius:12px;padding:14px 16px;font-family:Georgia,serif;font-size:15px;line-height:1.55;color:var(--pn-encre);position:relative;white-space:pre-line}
.pn-parch:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--pn-or);border-radius:12px 0 0 12px}
.pn-recap dt{color:var(--pn-encre2);font-size:12px;margin-top:10px}.pn-recap dd{margin:2px 0 0;font-size:14px}
.pn-prix{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--pn-papier2);font-size:14px}
.pn-prix.total{font-weight:600;font-size:16px;border-bottom:0}
.pn-erreur{background:#FBE9E5;color:var(--pn-rouge2);border-radius:10px;padding:10px 12px;font-size:14px;margin:10px 0}
.pn-ok{width:70px;height:70px;border-radius:50%;background:var(--pn-vert);color:#fff;font-size:34px;display:flex;align-items:center;justify-content:center;margin:20px auto 12px}
.pn-avis{border-left:3px solid var(--pn-or);padding:6px 10px;font-size:13px;color:#C9D3EC;margin-top:14px;font-style:italic}
.pn-avis b{font-style:normal;color:var(--pn-papier)}
.pn-cardn{background:#243560;border:1px solid #33456F;border-radius:12px;padding:12px 14px;margin-top:10px;font-size:14px}
.pn-cardn small{display:block;color:#B7C3E3;font-size:12px}
.pn-etapes{list-style:none;padding:0;margin:0}
.pn-etapes li{display:flex;gap:10px;align-items:flex-start;padding:8px 0;border-bottom:1px solid #2C3D66;font-size:14px}
.pn-etapes li span:first-child{width:22px;height:22px;border-radius:50%;background:#33456F;display:inline-flex;align-items:center;justify-content:center;font-size:12px;flex:none}
.pn-etapes li.ok span:first-child{background:var(--pn-vert)}
.pn-etapes li.now span:first-child{background:var(--pn-or);color:var(--pn-encre)}

.pn-video{background:#000;border-radius:16px;overflow:hidden;aspect-ratio:9/16;max-height:78vh;margin:0 auto}
.pn-video video{width:100%;height:100%;object-fit:contain;display:block;background:#000}
.pn-hero{position:relative;border-radius:22px;overflow:hidden;aspect-ratio:9/11;background:#0B1226}
.pn-hero img{width:100%;height:100%;object-fit:cover;display:block}
.pn-hero .sous{position:absolute;left:12px;right:12px;bottom:14px;font-family:Georgia,serif;font-size:15px;text-align:center;background:rgba(0,0,0,.45);padding:8px 10px;border-radius:8px}
.pn-flocon{position:absolute;width:5px;height:5px;border-radius:50%;background:#fff;opacity:.6;pointer-events:none;animation:pn-chute linear infinite}
@keyframes pn-chute{to{transform:translateY(70vh) translateX(14px);opacity:0}}
.pn-faq details{border-bottom:1px solid #2C3D66;padding:10px 0}
.pn-faq summary{cursor:pointer;font-family:Georgia,serif;font-size:16px}
.pn-faq p{font-size:14px;color:#C9D3EC;margin:8px 0 0}
.pn-foot{max-width:560px;margin:0 auto;padding:18px;font-size:12px;color:#9FB0D6;border-top:1px solid #2C3D66;text-align:center}

/* ---------- Documents imprimables (certificat, lettre) ---------- */
.pn-doc{background:#fff;color:var(--pn-encre);min-height:100vh;padding:24px 18px;font-family:Georgia,"Times New Roman",serif}
.pn-doc-feuille{max-width:640px;margin:0 auto;border:6px double var(--pn-or);padding:34px 30px;background:#FFFDF7;position:relative}
.pn-doc-sur{font-family:"Segoe UI",Roboto,Helvetica,Arial,sans-serif;font-size:12px;color:var(--pn-encre2);text-align:center;letter-spacing:.06em}
.pn-doc h1{font-size:34px;text-align:center;margin:12px 0 4px;font-weight:normal;color:var(--pn-nuit)}
.pn-doc .prenom{font-size:46px;color:var(--pn-rouge);text-align:center;margin:6px 0}
.pn-doc p{font-size:17px;line-height:1.6;margin:0 0 12px}
.pn-doc .lettre{white-space:pre-line;font-size:18px}
.pn-doc .signature{text-align:right;font-size:22px;margin-top:20px}
.pn-doc .bas{display:flex;justify-content:space-between;align-items:flex-end;margin-top:26px;gap:12px}
.pn-doc .sceau{display:inline-block;border:2px solid var(--pn-rouge);color:var(--pn-rouge);border-radius:50%;width:86px;height:86px;font-size:10px;text-align:center;line-height:1.2;padding-top:22px;transform:rotate(-8deg);flex:none}
.pn-doc .actions{max-width:640px;margin:18px auto 0;display:flex;gap:10px;font-family:"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.pn-doc .actions a,.pn-doc .actions button{flex:1;text-align:center;padding:12px;border-radius:10px;border:1.5px solid var(--pn-nuit);background:var(--pn-nuit);color:#fff;text-decoration:none;font-size:15px;cursor:pointer}
.pn-doc .actions a{background:transparent;color:var(--pn-nuit)}
@media print{
  .pn-doc{padding:0;background:#fff}
  .pn-doc .actions{display:none}
  .pn-doc-feuille{border-width:5px;page-break-inside:avoid}
  @page{margin:12mm}
}
.pn-btn.disabled{opacity:.45;pointer-events:none}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/pere-noel.css"
mkdir -p 'src/components'
cat > 'src/components/MenuButton.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function MenuButton({ tresors = true, pereNoel = false }: { tresors?: boolean; pereNoel?: boolean }) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : '';
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    window.addEventListener('keydown', esc);
    return () => {
      window.removeEventListener('keydown', esc);
      document.body.style.overflow = '';
    };
  }, [open]);

  return (
    <>
      <button
        className="menu-btn"
        onClick={() => setOpen(true)}
        aria-expanded={open}
        aria-label="Ouvrir le menu"
      >
        <span className="bars" aria-hidden="true"><i /><i /><i /></span>
        <span className="menu-word">Menu</span>
      </button>

      {open && (
        <div className="menu-panel" role="dialog" aria-modal="true" aria-label="Menu principal">
          <button className="menu-close" onClick={() => setOpen(false)} aria-label="Fermer le menu">
            ✕
          </button>
          <nav className="menu-nav" onClick={() => setOpen(false)}>
            <Link href="/">Accueil</Link>
            <Link href="/#evenements">Programme</Link>
            {tresors && <Link href="/tresors-de-noel">Trésors de Noël</Link>}
            {pereNoel && <Link href="/pere-noel">Le Père Noël te répond</Link>}
            <Link href="/#association">L&apos;association</Link>
            <Link href="/#benevoles">Bénévoles</Link>
          </nav>
          <div className="menu-foot mono">
            Comité des Fêtes de Limetz-Villez · Association loi 1901
          </div>
        </div>
      )}
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/MenuButton.tsx"
mkdir -p 'src/components'
cat > 'src/components/NavAdmin.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LIENS_ADMIN = [
  { href: '/admin', label: 'Tableau de bord' },
  { href: '/admin/evenements', label: 'Événements' },
  { href: '/admin/reservations', label: 'Réservations' },
  { href: '/admin/tresorerie', label: 'Trésorerie' },
  { href: '/admin/demandes', label: 'Demandes reçues' },
  { href: '/admin/tresors', label: 'Trésors de Noël' },
  { href: '/admin/pere-noel', label: '🎅 Père Noël vidéo' },
  { href: '/admin/roue', label: '🎡 Roue de la Rentrée' },
  { href: '/admin/partenaires', label: 'Partenaires' },
  { href: '/admin/association', label: 'Association' },
  { href: '/admin/parametres', label: 'Réglages du site' },
  { href: '/admin/maintenance', label: 'Maintenance' },
];

const LIENS_TRESORIER = [
  { href: '/admin/tresorerie', label: 'Trésorerie (lecture seule)' },
];

export default function NavAdmin({ role = 'admin' }: { role?: 'admin' | 'tresorier' }) {
  const path = usePathname();
  const [ouvert, setOuvert] = useState(false);
  useEffect(() => { setOuvert(false); }, [path]);
  const LIENS = role === 'tresorier' ? LIENS_TRESORIER : LIENS_ADMIN;
  const estActif = (href: string) => (href === '/admin' ? path === '/admin' : path.startsWith(href));
  const courant = LIENS.find((l) => estActif(l.href))?.label ?? 'Menu';

  return (
    <nav className={`adm-nav${ouvert ? ' ouvert' : ''}`}>
      <button type="button" className="adm-nav-btn" aria-expanded={ouvert} onClick={() => setOuvert((v) => !v)}>
        <span>{courant}</span>
        <span aria-hidden="true">{ouvert ? '✕' : '☰'}</span>
      </button>
      <div className="adm-nav-liens">
        {LIENS.map((l) => (
          <Link key={l.href} href={l.href} className={estActif(l.href) ? 'on' : ''}>
            {l.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/NavAdmin.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/ActionsCommande.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { genererCommande, marquerPayee, refaireVideo, regenererScript, renvoyerEmailVideo, supprimerCommande, verifierCommande } from '@/app/pere-noel-actions';
import type { CommandePn } from '@/lib/pere-noel/types';

export default function ActionsCommande({ c }: { c: CommandePn }) {
  const [pending, start] = useTransition();
  const [confirm, setConfirm] = useState(false);
  const router = useRouter();
  const run = (fn: () => Promise<unknown>) => start(async () => { await fn(); router.refresh(); });
  const payee = c.statut === 'payee';

  return (
    <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', opacity: pending ? .6 : 1 }}>
      {!payee && <button className="btn btn-y btn-sm" disabled={pending} onClick={() => run(() => marquerPayee(c.id))}>Marquer comme payée</button>}
      {payee && (c.gen_statut === 'a_faire' || c.gen_statut === 'erreur') && (
        <button className="btn btn-y btn-sm" disabled={pending} onClick={() => run(() => genererCommande(c.id))}>{c.gen_statut === 'erreur' ? '↻ Reprendre la génération' : '▶ Générer'}</button>
      )}
      {payee && c.gen_statut === 'video' && <button className="btn btn-y btn-sm" disabled={pending} onClick={() => run(() => verifierCommande(c.id))}>↻ Vérifier chez HeyGen</button>}
      {payee && c.script && <button className="btn btn-w btn-sm" disabled={pending} onClick={() => run(() => regenererScript(c.id))}>Réécrire le script</button>}
      {payee && c.audio_url && c.gen_statut !== 'audio' && <button className="btn btn-w btn-sm" disabled={pending} onClick={() => run(() => refaireVideo(c.id))}>Refaire la vidéo (même script)</button>}
      {payee && c.video_url && <button className="btn btn-w btn-sm" disabled={pending} onClick={() => run(() => renvoyerEmailVideo(c.id))}>Renvoyer l’email</button>}
      {!confirm
        ? <button className="btn btn-w btn-sm" disabled={pending} onClick={() => setConfirm(true)}>Supprimer</button>
        : <button className="btn btn-danger btn-sm" disabled={pending} onClick={() => start(() => supprimerCommande(c.id))}>Confirmer la suppression</button>}
      {pending && <span style={{ fontSize: '.85rem', color: '#6b6560', alignSelf: 'center' }}>En cours, cela peut prendre jusqu’à une minute…</span>}
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/ActionsCommande.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/BasculeModulePn.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useState, useTransition } from 'react';
import { basculerModulePn } from '@/app/pere-noel-actions';

export default function BasculeModulePn({ actif }: { actif: boolean }) {
  const [confirm, setConfirm] = useState(false);
  const [pending, start] = useTransition();
  return (
    <div className="panel" style={{ borderLeft: `10px solid ${actif ? '#9BD44F' : '#6b6560'}`, opacity: pending ? .7 : 1 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap', alignItems: 'center' }}>
        <div>
          <p style={{ fontFamily: 'Anton, sans-serif', textTransform: 'uppercase', fontSize: '1.3rem' }}>{actif ? '🟢 Module en ligne' : '⚫ Module désactivé'}</p>
          <p style={{ color: '#6b6560', marginTop: '.3rem' }}>
            {actif ? 'Visible dans le menu du site et accessible à l’adresse /pere-noel. Les commandes s’ouvrent séparément dans les réglages.' : 'Retiré du menu ; les visiteurs voient « pas disponible pour le moment ». Vous gardez l’accès en tant qu’admin.'}
          </p>
        </div>
        {actif
          ? <button className="btn btn-w btn-sm" onClick={() => setConfirm(true)}>Désactiver le module</button>
          : <button className="btn btn-y btn-sm" onClick={() => start(() => basculerModulePn(true))}>Activer le module</button>}
      </div>
      {confirm && (
        <div onClick={() => setConfirm(false)} style={{ position: 'fixed', inset: 0, zIndex: 90, background: 'rgba(20,16,20,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem' }}>
          <div className="panel" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 440, margin: 0 }}>
            <h2>Désactiver le Père Noël ?</h2>
            <p>Le lien disparaît du menu et les pages ne sont plus accessibles au public. Les commandes et vidéos sont conservées, les familles gardent l’accès à leur espace.</p>
            <div style={{ display: 'flex', gap: '.6rem', marginTop: '1.2rem', justifyContent: 'flex-end' }}>
              <button className="btn btn-w btn-sm" onClick={() => setConfirm(false)}>Annuler</button>
              <button className="btn btn-k btn-sm" onClick={() => { setConfirm(false); start(() => basculerModulePn(false)); }}>Désactiver</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/BasculeModulePn.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/BoutonImprimer.tsx' <<'EOF_PN_FICHIER'
'use client';
export default function BoutonImprimer() {
  return <button type="button" onClick={() => window.print()}>Imprimer ou enregistrer en PDF</button>;
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/BoutonImprimer.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/BoutonVerifier.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useEffect, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { verifierToutes } from '@/app/pere-noel-actions';

/** Vérifie les vidéos en cours et lance les commandes en attente (si auto). Se relance seul toutes les 60 s tant que la page est ouverte. */
export default function BoutonVerifier({ auto = true }: { auto?: boolean }) {
  const [pending, start] = useTransition();
  const [info, setInfo] = useState('');
  const router = useRouter();
  const lancer = () => start(async () => {
    const r = await verifierToutes();
    setInfo(`${r.verifiees} vérifiée${r.verifiees > 1 ? 's' : ''}, ${r.lancees} lancée${r.lancees > 1 ? 's' : ''}`);
    router.refresh();
  });
  useEffect(() => {
    if (!auto) return;
    const t = setInterval(lancer, 60_000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [auto]);
  return (
    <button className="btn btn-y btn-sm" onClick={lancer} disabled={pending} title={info}>
      {pending ? 'Vérification…' : '↻ Vérifier les vidéos'}
    </button>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/BoutonVerifier.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/FormCommande.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState, useState } from 'react';
import { commander, type Etat } from '@/app/pere-noel-actions';
import { euros } from '@/lib/sumup';
import { LIBELLE_SAGESSE, type Sagesse, type TonSecret } from '@/lib/pere-noel/types';

const EFFORTS = ['Dormir dans son lit', 'Goûter les légumes', 'Ranger sa chambre', 'Être gentil avec son frère ou sa sœur', 'Moins d’écrans', 'Se brosser les dents sans râler'];
const NOMS_ETAPES = ['L’enfant', 'Sa lettre', 'Les détails', 'Le secret', 'Récapitulatif'];

export default function FormCommande({ prix, test }: { prix: number; test: boolean }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(commander, null);
  const [etape, setEtape] = useState(1);
  const [f, setF] = useState({
    enfant_prenom: '', prononciation: '', age: '', genre: '', sagesse: 'tres_sage' as Sagesse,
    lettre: '', cadeaux: '', fierte: '', passion: '', effort: '', effortAutre: '', salut: '',
    secret: '', ton_secret: 'rigolo' as TonSecret, parent_prenom: '', email: '',
  });
  const maj = (k: keyof typeof f, v: string) => setF((x) => ({ ...x, [k]: v }));
  const enfantOk = f.enfant_prenom.trim().length > 0 && Number(f.age) > 0;
  const lettreOk = f.lettre.trim().length > 0 || f.cadeaux.trim().length > 0;
  const parentOk = f.parent_prenom.trim().length > 0 && f.email.includes('@');
  const effortFinal = f.effort === 'autre' ? f.effortAutre : f.effort;

  return (
    <form action={action}>
      <input type="hidden" name="test" value={test ? '1' : '0'} />
      <input type="hidden" name="effort" value={effortFinal} />
      <div className="pn-steps" aria-hidden="true">{[1, 2, 3, 4, 5].map((n) => <i key={n} className={n <= etape ? 'on' : ''} />)}</div>
      <div className="pn-stepname">Étape {etape} sur 5 · {NOMS_ETAPES[etape - 1]}</div>
      {etat?.erreur && <p className="pn-erreur" role="alert">{etat.erreur}</p>}
      {test && <p className="pn-cardn pn-mini">Mode test administrateur : pas de paiement, la commande est créée directement.</p>}

      {/* 1. L'enfant */}
      <section className="pn-carte" hidden={etape !== 1}>
        <h2>Pour qui est cette vidéo ?</h2>
        <p className="pn-l">Le Père Noël prononcera son prénom, écrivez-le comme on le dit.</p>
        <div className="pn-champ"><label htmlFor="enfant_prenom">Prénom de l&apos;enfant</label>
          <input id="enfant_prenom" name="enfant_prenom" value={f.enfant_prenom} onChange={(e) => maj('enfant_prenom', e.target.value)} autoComplete="off" /></div>
        <div className="pn-champ"><label htmlFor="prononciation">Comment on le prononce (si besoin)</label>
          <input id="prononciation" name="prononciation" placeholder="Ex. : Maël se dit « Ma-el »" value={f.prononciation} onChange={(e) => maj('prononciation', e.target.value)} /></div>
        <div className="pn-row">
          <div className="pn-champ"><label htmlFor="age">Âge</label>
            <input id="age" name="age" type="number" inputMode="numeric" min={1} max={17} value={f.age} onChange={(e) => maj('age', e.target.value)} /></div>
          <div className="pn-champ"><label htmlFor="genre">Fille ou garçon</label>
            <select id="genre" name="genre" value={f.genre} onChange={(e) => maj('genre', e.target.value)}>
              <option value="">Je préfère ne pas dire</option><option value="fille">Fille</option><option value="garcon">Garçon</option></select></div>
        </div>
        <div className="pn-champ"><label>A-t-il été sage cette année ?</label>
          <div className="pn-opts">
            {([['presque', '~'], ['tres_sage', '★'], ['le_plus_sage', '★★']] as [Sagesse, string][]).map(([v, s]) => (
              <label key={v} className={f.sagesse === v ? 'on' : ''}><input type="radio" name="sagesse" value={v} checked={f.sagesse === v} onChange={() => maj('sagesse', v)} /><b>{s}</b>{LIBELLE_SAGESSE[v]}</label>
            ))}
          </div></div>
        <button type="button" className="pn-btn" disabled={!enfantOk} onClick={() => setEtape(2)}>Continuer</button>
      </section>

      {/* 2. Sa lettre */}
      <section className="pn-carte" hidden={etape !== 2}>
        <h2>Qu&apos;est-ce que {f.enfant_prenom || 'votre enfant'} veut dire au Père Noël ?</h2>
        <p className="pn-l">Écrivez ce qu&apos;il vous dicte, avec ses mots. C&apos;est à cette lettre que le Père Noël va répondre. S&apos;il pose une question, le Père Noël y répondra.</p>
        <div className="pn-champ"><label htmlFor="lettre">Sa lettre</label>
          <textarea id="lettre" name="lettre" placeholder="Cher Père Noël, cette année j'ai appris à…" value={f.lettre} onChange={(e) => maj('lettre', e.target.value)} maxLength={1500} /></div>
        <div className="pn-champ"><label htmlFor="cadeaux">Ce qu&apos;il demande comme cadeau (pour que le Père Noël en parle)</label>
          <input id="cadeaux" name="cadeaux" placeholder="Un microscope, un livre sur les dauphins" value={f.cadeaux} onChange={(e) => maj('cadeaux', e.target.value)} /></div>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(1)}>Retour</button>
          <button type="button" className="pn-btn" disabled={!lettreOk} onClick={() => setEtape(3)}>Continuer</button>
        </div>
      </section>

      {/* 3. Les détails */}
      <section className="pn-carte" hidden={etape !== 3}>
        <h2>Ce que le Père Noël sait sur {f.enfant_prenom || 'lui'}</h2>
        <p className="pn-l">Tout est facultatif. Plus vous remplissez, plus la vidéo est bluffante.</p>
        <div className="pn-champ"><label htmlFor="fierte">Sa grande fierté de l&apos;année</label>
          <input id="fierte" name="fierte" placeholder="A appris à faire du vélo sans les petites roues" value={f.fierte} onChange={(e) => maj('fierte', e.target.value)} /></div>
        <div className="pn-champ"><label htmlFor="passion">Son doudou, son animal ou sa passion</label>
          <input id="passion" name="passion" placeholder="Son lapin Caramel et les dauphins" value={f.passion} onChange={(e) => maj('passion', e.target.value)} /></div>
        <div className="pn-champ"><label>Un petit effort à encourager (le Père Noël le demande gentiment)</label>
          <div className="pn-chips">
            {EFFORTS.map((e) => <label key={e} className={f.effort === e ? 'on' : ''}><input type="radio" name="effort_choix" checked={f.effort === e} onChange={() => maj('effort', e)} />{e}</label>)}
            <label className={f.effort === 'autre' ? 'on' : ''}><input type="radio" name="effort_choix" checked={f.effort === 'autre'} onChange={() => maj('effort', 'autre')} />Autre…</label>
            {f.effort && <label className="on" style={{ background: 'transparent', color: 'var(--pn-encre2)', borderStyle: 'dashed' }} onClick={() => maj('effort', '')}>✕ aucun</label>}
          </div>
          {f.effort === 'autre' && <input style={{ marginTop: 8 }} placeholder="Ex. : arrêter de mordre son frère" value={f.effortAutre} onChange={(e) => maj('effortAutre', e.target.value)} />}
        </div>
        <div className="pn-champ"><label htmlFor="salut">Une personne à saluer (mamie, la maîtresse, le petit frère…)</label>
          <input id="salut" name="salut" placeholder="Mamie Jacqueline" value={f.salut} onChange={(e) => maj('salut', e.target.value)} /></div>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(2)}>Retour</button>
          <button type="button" className="pn-btn" onClick={() => setEtape(4)}>Continuer</button>
        </div>
      </section>

      {/* 4. Le secret */}
      <section className="pn-carte" hidden={etape !== 4}>
        <h2>Un mot que seul le Père Noël pouvait connaître</h2>
        <p className="pn-l">Un détail que votre enfant n&apos;a dit à personne, une petite bêtise pardonnée, un souvenir… Le Père Noël le glisse dans la vidéo. C&apos;est ce qui le fera écarquiller les yeux. Facultatif.</p>
        <div className="pn-champ"><label htmlFor="secret">Le message secret</label>
          <textarea id="secret" name="secret" placeholder="Elle a caché les bonbons d'Halloween dans sa boîte à chaussures et pense que personne ne le sait." value={f.secret} onChange={(e) => maj('secret', e.target.value)} maxLength={500} style={{ minHeight: 90 }} /></div>
        <div className="pn-champ"><label>Comment le Père Noël doit le dire</label>
          <div className="pn-opts">
            {([['rigolo', '☺', 'En rigolant'], ['tendre', '♥', 'Avec tendresse'], ['serieux', '!', 'Un peu sérieux']] as [TonSecret, string, string][]).map(([v, s, l]) => (
              <label key={v} className={f.ton_secret === v ? 'on' : ''}><input type="radio" name="ton_secret" value={v} checked={f.ton_secret === v} onChange={() => maj('ton_secret', v)} /><b>{s}</b>{l}</label>
            ))}
          </div></div>
        <p className="pn-l pn-mini" style={{ marginTop: 12 }}>Le message secret n&apos;apparaît que dans la vidéo, jamais sur la lettre ni le certificat.</p>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(3)}>Retour</button>
          <button type="button" className="pn-btn" onClick={() => setEtape(5)}>Continuer</button>
        </div>
      </section>

      {/* 5. Récap + parent */}
      <section className="pn-carte" hidden={etape !== 5}>
        <h2>On envoie la lettre de {f.enfant_prenom || 'votre enfant'} ?</h2>
        <dl className="pn-recap" style={{ margin: 0 }}>
          <dt>Pour</dt><dd>{f.enfant_prenom}, {f.age} ans, {LIBELLE_SAGESSE[f.sagesse]}</dd>
          {(f.fierte || f.passion || f.salut || effortFinal) && <><dt>Le Père Noël va parler de</dt><dd>{[f.fierte, f.passion, f.salut, effortFinal].filter(Boolean).join(' · ')}</dd></>}
          {f.secret && <><dt>Message secret</dt><dd>Oui, {({ rigolo: 'en rigolant', tendre: 'avec tendresse', serieux: 'un peu sérieux' })[f.ton_secret]}</dd></>}
        </dl>
        <div className="pn-champ"><label htmlFor="parent_prenom">Votre prénom</label>
          <input id="parent_prenom" name="parent_prenom" autoComplete="given-name" value={f.parent_prenom} onChange={(e) => maj('parent_prenom', e.target.value)} /></div>
        <div className="pn-champ"><label htmlFor="email">Votre email (pour recevoir la vidéo)</label>
          <input id="email" name="email" type="email" inputMode="email" autoComplete="email" value={f.email} onChange={(e) => maj('email', e.target.value)} /></div>
        <div style={{ marginTop: 14 }}>
          <div className="pn-prix"><span>Vidéo réponse du Père Noël</span><span>{test ? 'test' : euros(prix)}</span></div>
          <div className="pn-prix"><span>Lettre écrite + certificat d&apos;enfant sage</span><span>inclus</span></div>
          <div className="pn-prix total"><span>Total</span><span>{test ? '0 €' : euros(prix)}</span></div>
        </div>
        <button type="submit" className="pn-btn vert" disabled={!parentOk || pending}>
          {pending ? 'Redirection…' : test ? 'Créer la commande de test' : `Payer ${euros(prix)} par carte`}
        </button>
        <p className="pn-l pn-mini pn-centre" style={{ marginTop: 10 }}>Paiement sécurisé par SumUp. Vidéo livrée par email, garantie satisfait ou refait.</p>
        <button type="button" className="pn-lien" onClick={() => setEtape(1)}>Modifier les réponses</button>
      </section>
    </form>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/FormCommande.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/FormReglagesPn.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState } from 'react';
import { majReglagesPn, type Etat } from '@/app/pere-noel-actions';
import ChampImage from '@/components/ChampImage';
import type { ReglagesPn } from '@/lib/pere-noel/types';

type Cles = { anthropic: boolean; elevenlabs: boolean; heygen: boolean; voixEnv: string };

export default function FormReglagesPn({ r, cles }: { r: ReglagesPn; cles: Cles }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(majReglagesPn, null);
  const ok = (b: boolean) => <span className={`pill ${b ? 'done' : 'off'}`}>{b ? 'présente' : 'absente'}</span>;
  return (
    <form action={action}>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <div className="panel">
        <h2>Clés API (variables d’environnement Vercel)</h2>
        <p style={{ fontSize: '.9rem' }}>ANTHROPIC_API_KEY {ok(cles.anthropic)} · ELEVENLABS_API_KEY {ok(cles.elevenlabs)} · HEYGEN_API_KEY {ok(cles.heygen)}</p>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.4rem' }}>Les clés ne se saisissent pas ici : ajoutez-les dans Vercel puis redéployez.</p>
      </div>

      <div className="panel">
        <h2>Textes et prix</h2>
        <div className="field"><label htmlFor="titre">Titre</label><input id="titre" name="titre" defaultValue={r.titre} /></div>
        <div className="field"><label htmlFor="accroche">Accroche (page d’accueil)</label><input id="accroche" name="accroche" defaultValue={r.accroche} /></div>
        <div className="row2">
          <div className="field"><label htmlFor="prix">Prix (€)</label><input id="prix" name="prix" type="number" step="0.1" min={0} defaultValue={r.prix_centimes / 100} /></div>
          <div className="field"><label htmlFor="delai_texte">Délai annoncé</label><input id="delai_texte" name="delai_texte" defaultValue={r.delai_texte} /></div>
        </div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="commandes_ouvertes" defaultChecked={r.commandes_ouvertes} style={{ width: 'auto' }} /> Commandes ouvertes au public</label>
      </div>

      <div className="panel">
        <h2>Génération</h2>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="generation_auto" defaultChecked={r.generation_auto} style={{ width: 'auto' }} /> Lancer la génération automatiquement dès le paiement</label>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="relecture_script" defaultChecked={r.relecture_script} style={{ width: 'auto' }} /> Relire et valider le script avant l’audio et la vidéo (conseillé au début)</label>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Génération manuelle = rien ne part chez HeyGen tant que vous n’avez pas cliqué « Générer » sur la commande. Utile tant que le compte HeyGen n’a pas de crédits.</p>
        <div className="field"><label htmlFor="duree_cible_sec">Durée cible de la vidéo (secondes, 30 à 120)</label><input id="duree_cible_sec" name="duree_cible_sec" type="number" min={30} max={120} defaultValue={r.duree_cible_sec} /></div>
        <div className="field"><label htmlFor="consignes_script">Consignes supplémentaires pour l’écriture du script (facultatif)</label>
          <textarea id="consignes_script" name="consignes_script" rows={3} defaultValue={r.consignes_script} placeholder="Ex. : mentionner que le Père Noël passera aussi par le village le 20 décembre." /></div>
      </div>

      <div className="panel">
        <h2>Le Père Noël (image)</h2>
        <ChampImage name="image_url" label="Portrait du Père Noël, format vertical 9:16, bouche bien visible" valeurInitiale={r.image_url} dossier="pere-noel" aide="C’est cette image qui est animée par HeyGen pour chaque vidéo." />
        <div className="field"><label htmlFor="expressivite">Expressivité HeyGen</label>
          <select id="expressivite" name="expressivite" defaultValue={r.expressivite}><option value="low">Faible (sobre)</option><option value="medium">Moyenne (conseillé)</option><option value="high">Forte (rires, gestes, risque d’artefacts)</option></select></div>
        <div className="field"><label htmlFor="motion_prompt">Consigne de mouvement (HeyGen)</label><textarea id="motion_prompt" name="motion_prompt" rows={2} defaultValue={r.motion_prompt} /></div>
      </div>

      <div className="panel">
        <h2>La voix (ElevenLabs)</h2>
        <div className="field"><label htmlFor="voice_id">Voice ID</label><input id="voice_id" name="voice_id" defaultValue={r.voice_id ?? ''} placeholder={cles.voixEnv ? `Par défaut : ${cles.voixEnv} (variable ELEVENLABS_VOICE_ID)` : 'Ex. : MDLAMJ0jxkpYkjXbmG4t'} /></div>
        <div className="row2">
          <div className="field"><label htmlFor="modele_voix">Modèle</label>
            <select id="modele_voix" name="modele_voix" defaultValue={r.modele_voix}><option value="eleven_multilingual_v2">Multilingual v2 (stable)</option><option value="eleven_v3">Eleven v3 (plus expressif)</option><option value="eleven_turbo_v2_5">Turbo v2.5 (rapide, moins cher)</option></select></div>
          <div className="field"><label htmlFor="vitesse">Vitesse (0,7 à 1,2)</label><input id="vitesse" name="vitesse" type="number" step="0.01" min={0.7} max={1.2} defaultValue={r.vitesse} /></div>
        </div>
        <div className="row3">
          <div className="field"><label htmlFor="stabilite">Stabilité (0 à 1)</label><input id="stabilite" name="stabilite" type="number" step="0.05" min={0} max={1} defaultValue={r.stabilite} /></div>
          <div className="field"><label htmlFor="similarite">Similarité (0 à 1)</label><input id="similarite" name="similarite" type="number" step="0.05" min={0} max={1} defaultValue={r.similarite} /></div>
          <div className="field"><label htmlFor="style_voix">Style (0 à 1)</label><input id="style_voix" name="style_voix" type="number" step="0.05" min={0} max={1} defaultValue={r.style_voix} /></div>
        </div>
      </div>

      <button className="btn btn-y" type="submit" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer les réglages'}</button>
    </form>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/FormReglagesPn.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/FormScript.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState } from 'react';
import { validerScript, type Etat } from '@/app/pere-noel-actions';
import type { CommandePn } from '@/lib/pere-noel/types';

export default function FormScript({ c, modifiable }: { c: CommandePn; modifiable: boolean }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(validerScript, null);
  const mots = (c.script ?? '').split(/\s+/).filter(Boolean).length;
  return (
    <form action={action} className="panel">
      <h2>Script du Père Noël <small style={{ fontWeight: 'normal', color: '#6b6560' }}>· {mots} mots ≈ {Math.round(mots / 140 * 60)} s</small></h2>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
      <input type="hidden" name="id" value={c.id} />
      <div className="field"><label htmlFor="script">Ce que dit le Père Noël (lu par la voix)</label>
        <textarea id="script" name="script" rows={12} defaultValue={c.script ?? ''} readOnly={!modifiable} /></div>
      <div className="field"><label htmlFor="lettre_reponse">Lettre écrite (imprimable)</label>
        <textarea id="lettre_reponse" name="lettre_reponse" rows={8} defaultValue={c.lettre_reponse ?? ''} readOnly={!modifiable} /></div>
      <div className="field"><label htmlFor="certificat_mention">Mention du certificat</label>
        <input id="certificat_mention" name="certificat_mention" defaultValue={c.certificat_mention ?? ''} readOnly={!modifiable} /></div>
      {modifiable && (
        <button className="btn btn-y btn-sm" type="submit" disabled={pending}>
          {pending ? 'Audio et vidéo en cours de lancement…' : c.gen_statut === 'relecture' ? '✓ Valider et lancer audio + vidéo' : 'Enregistrer et relancer audio + vidéo'}
        </button>
      )}
      {!modifiable && <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Le script est figé pendant la génération. Utilisez « Réécrire le script » ou « Refaire la vidéo » pour repartir.</p>}
    </form>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/FormScript.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/NavPnAdmin.tsx' <<'EOF_PN_FICHIER'
'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const ONGLETS = [
  { href: '/admin/pere-noel', label: 'Commandes' },
  { href: '/admin/pere-noel/reglages', label: 'Réglages' },
];

export default function NavPnAdmin() {
  const path = usePathname();
  return (
    <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap', marginBottom: '1.6rem' }}>
      {ONGLETS.map((o) => {
        const actif = o.href === '/admin/pere-noel' ? !path.startsWith('/admin/pere-noel/reglages') : path.startsWith(o.href);
        return <Link key={o.href} href={o.href} className={`btn btn-sm ${actif ? 'btn-k' : 'btn-w'}`}>{o.label}</Link>;
      })}
      <Link href="/pere-noel/commander?test=1" target="_blank" className="btn btn-sm btn-y">+ Commande de test</Link>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/NavPnAdmin.tsx"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/db.ts' <<'EOF_PN_FICHIER'
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
EOF_PN_FICHIER
echo "  ✓ src/lib/pere-noel/db.ts"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/emails.ts' <<'EOF_PN_FICHIER'
import 'server-only';
import type { CommandePn, ReglagesPn } from './types';

const NUIT = '#1B2A4A';
const ROUGE = '#B8322E';
const OR = '#D4A64A';
const PAPIER = '#F7EFDD';
const ENCRE = '#2A2116';

function base() { return process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000'; }

function gabarit(titre: string, corps: string) {
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${titre}</title></head>
<body style="margin:0;padding:0;background:#EFEAE0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#EFEAE0;padding:28px 12px;"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:${PAPIER};border:3px solid ${NUIT};">
<tr><td style="background:${NUIT};padding:30px 28px;text-align:center;">
<div style="font-family:Georgia,serif;font-size:14px;color:${OR};letter-spacing:1px;">Le Père Noël te répond</div>
<h1 style="margin:12px 0 0;color:${PAPIER};font-family:Georgia,serif;font-weight:normal;font-size:26px;line-height:1.2;">${titre}</h1>
</td></tr>
<tr><td style="padding:26px 28px;color:${ENCRE};font-size:15px;line-height:1.6;">${corps}</td></tr>
<tr><td style="padding:16px 28px 22px;border-top:1px solid #E2D6B6;font-size:12px;color:#6B5E4C;">Une action du Comité des Fêtes. Les bénéfices financent les événements de l'année.</td></tr>
</table></td></tr></table></body></html>`;
}

function bouton(url: string, libelle: string) {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:22px auto;"><tr><td style="background:${ROUGE};padding:14px 26px;text-align:center;">
<a href="${url}" style="color:#ffffff;text-decoration:none;font-family:Georgia,serif;font-size:16px;">${libelle}</a></td></tr></table>`;
}

async function envoyer(to: string, subject: string, html: string, text: string) {
  if (!process.env.RESEND_API_KEY) { console.warn('[pere-noel] RESEND_API_KEY absente, email non envoyé'); return false; }
  const from = process.env.RESEND_FROM_EMAIL ?? 'Comité des Fêtes de Limetz-Villez <billetterie@cdf-limetzvillez.fr>';
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from, to: [to], subject, html, text }),
  });
  if (!r.ok) console.error('[pere-noel] Resend', r.status, await r.text());
  return r.ok;
}

/** Après paiement : la lettre est partie, certificat et lettre écrite dès que le script est prêt. */
export async function emailConfirmation(c: CommandePn, r: ReglagesPn) {
  const lien = `${base()}/pere-noel/ma-video/${c.token}`;
  const corps = `
<p>Bonjour ${c.parent_prenom || ''},</p>
<p>La lettre de ${c.enfant_prenom} est bien arrivée au Pôle Nord. Le Père Noël prépare sa réponse en vidéo, vous la recevrez par email ${r.delai_texte}.</p>
<p>Votre espace personnel vous permettra de regarder la vidéo, de la télécharger et d'imprimer la lettre écrite du Père Noël ainsi que le certificat d'enfant sage :</p>
${bouton(lien, 'Ouvrir mon espace')}
<p style="font-size:13px;color:#6B5E4C;">Référence de commande : ${c.reference}. Ce lien est personnel, ne le partagez pas avec votre enfant.</p>`;
  const text = `Bonjour ${c.parent_prenom || ''},\n\nLa lettre de ${c.enfant_prenom} est bien arrivée au Pôle Nord. Vous recevrez la vidéo ${r.delai_texte}.\n\nVotre espace : ${lien}\nRéférence : ${c.reference}\n\nComité des Fêtes de Limetz-Villez`;
  return envoyer(c.email, `La lettre de ${c.enfant_prenom} est arrivée au Pôle Nord`, gabarit('La lettre est bien arrivée', corps), text);
}

/** Vidéo prête : lien vers l'espace avec lecture et téléchargement. */
export async function emailVideoPrete(c: CommandePn) {
  const lien = `${base()}/pere-noel/ma-video/${c.token}`;
  const corps = `
<p>Bonjour ${c.parent_prenom || ''},</p>
<p>La réponse du Père Noël à ${c.enfant_prenom} est prête. Elle vous attend dans votre espace, avec le bouton de téléchargement, la lettre écrite et le certificat à imprimer.</p>
${bouton(lien, 'Voir la vidéo du Père Noël')}
<p>Un conseil : ne la montrez pas tout de suite. Le soir, dans le noir, sur la télé du salon, l'effet est décuplé.</p>
<p style="font-size:13px;color:#6B5E4C;">Pensez à télécharger la vidéo, elle reste disponible jusqu'au 31 janvier. Référence : ${c.reference}.</p>`;
  const text = `Bonjour ${c.parent_prenom || ''},\n\nLa réponse du Père Noël à ${c.enfant_prenom} est prête : ${lien}\n\nPensez à la télécharger, elle reste disponible jusqu'au 31 janvier.\n\nComité des Fêtes de Limetz-Villez`;
  return envoyer(c.email, `Le Père Noël a répondu à ${c.enfant_prenom}`, gabarit(`La vidéo de ${c.enfant_prenom} est prête`, corps), text);
}
EOF_PN_FICHIER
echo "  ✓ src/lib/pere-noel/emails.ts"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/ia.ts' <<'EOF_PN_FICHIER'
import 'server-only';
import type { CommandePn, ReglagesPn } from './types';
import { LIBELLE_SAGESSE } from './types';

/* =========================================================
   1. SCRIPT — Claude écrit la réponse du Père Noël
   ========================================================= */
export interface ContenuGenere {
  script: string;            // ce que dit le Père Noël (lu par ElevenLabs)
  lettre: string;            // réponse écrite, imprimable
  mention: string;           // une phrase pour le certificat d'enfant sage
}

function consignes(c: CommandePn, r: ReglagesPn) {
  const mots = Math.round((r.duree_cible_sec / 60) * 140); // ~140 mots par minute à vitesse lente
  const prenom = c.prononciation?.trim() ? `${c.enfant_prenom} (se prononce « ${c.prononciation.trim()} »)` : c.enfant_prenom;
  const genre = c.genre === 'fille' ? 'une fille' : c.genre === 'garcon' ? 'un garçon' : 'un enfant';
  const ton = { rigolo: 'en riant, complice', tendre: 'avec tendresse', serieux: 'un peu sérieux mais bienveillant' }[c.ton_secret];
  const lignes = [
    `Prénom : ${prenom}`,
    `Âge : ${c.age ?? 'inconnu'} ans, ${genre}`,
    `Sagesse cette année : ${LIBELLE_SAGESSE[c.sagesse]}`,
    c.lettre ? `Lettre de l'enfant au Père Noël : « ${c.lettre.trim()} »` : null,
    c.cadeaux ? `Ce qu'il demande : ${c.cadeaux.trim()}` : null,
    c.fierte ? `Sa grande fierté de l'année : ${c.fierte.trim()}` : null,
    c.passion ? `Son doudou, son animal ou sa passion : ${c.passion.trim()}` : null,
    c.effort ? `Petit effort à encourager gentiment : ${c.effort.trim()}` : null,
    c.salut ? `Personne à saluer : ${c.salut.trim()}` : null,
    c.secret ? `Message secret des parents, à glisser ${ton} : « ${c.secret.trim()} »` : null,
  ].filter(Boolean).join('\n');

  return `Tu es le Père Noël. Tu enregistres un message vidéo personnel pour un enfant, en réponse à sa lettre.

INFORMATIONS SUR L'ENFANT
${lignes}

RÈGLES DU SCRIPT (ce que tu dis à voix haute)
- Français de France, tutoiement, phrases courtes, vocabulaire adapté à l'âge.
- Environ ${mots} mots (${r.duree_cible_sec} secondes à voix lente). Ni plus court, ni beaucoup plus long.
- Structure : salut chaleureux avec le prénom → tu réponds à ce que l'enfant a écrit (réponds à ses questions s'il en pose) → sa fierté → le message secret des parents si présent, présenté comme quelque chose que seul le Père Noël pouvait savoir → l'effort à encourager, formulé positivement → salutation à la personne indiquée → au revoir en donnant rendez-vous la nuit de Noël.
- Dis « Ho ho ho ! » une fois au début, après une première phrase, et une fois à la fin. Écris-le « Ho, ho, ho ! ».
- Ne promets jamais un cadeau précis : dis que tu as bien noté sa liste et que tu feras de ton mieux.
- Rien qui fasse peur, aucune menace, jamais de « si tu n'es pas sage ». Un enfant « presque sage » est taquiné avec douceur.
- Pas de mention d'intelligence artificielle, de vidéo, d'ordinateur ou de parents qui ont écrit.
- Utilise « … » pour marquer les pauses et « ! » pour l'enthousiasme, la voix synthétique s'en sert.
- Le prénom doit apparaître au moins trois fois.
${r.consignes_script ? `- Consignes supplémentaires : ${r.consignes_script}` : ''}

RÈGLES DE LA LETTRE (réponse écrite, imprimée par les parents)
- 120 à 160 mots, même contenu que le script mais reformulé, commence par « Ma chère ${c.enfant_prenom}, » ou « Mon cher ${c.enfant_prenom}, », termine par « Le Père Noël ». Sans le message secret.

RÈGLES DE LA MENTION (certificat d'enfant sage)
- Une seule phrase, 12 à 20 mots, qui commence par « pour » et cite une fierté ou une qualité de l'enfant. Sans le message secret.

Réponds UNIQUEMENT avec un objet JSON valide, sans texte autour ni balises de code :
{"script": "...", "lettre": "...", "mention": "..."}`;
}

export async function genererContenu(c: CommandePn, r: ReglagesPn): Promise<ContenuGenere> {
  const cle = process.env.ANTHROPIC_API_KEY;
  if (!cle) throw new Error('ANTHROPIC_API_KEY manquante');
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': cle, 'anthropic-version': '2023-06-01', 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: process.env.ANTHROPIC_MODEL ?? 'claude-sonnet-4-6',
      max_tokens: 1500,
      messages: [{ role: 'user', content: consignes(c, r) }],
    }),
  });
  if (!res.ok) throw new Error(`Claude ${res.status} : ${(await res.text()).slice(0, 200)}`);
  const data = await res.json();
  const texte: string = (data.content ?? []).filter((b: any) => b.type === 'text').map((b: any) => b.text).join('\n');
  const propre = texte.replace(/```json|```/g, '').trim();
  const debut = propre.indexOf('{');
  const fin = propre.lastIndexOf('}');
  let obj: any;
  try { obj = JSON.parse(propre.slice(debut, fin + 1)); } catch { throw new Error('Réponse de Claude illisible (JSON attendu).'); }
  if (!obj.script || !obj.lettre) throw new Error('Réponse de Claude incomplète.');
  return { script: String(obj.script).trim(), lettre: String(obj.lettre).trim(), mention: String(obj.mention ?? '').trim() };
}

/* =========================================================
   2. VOIX — ElevenLabs Text to Speech
   ========================================================= */
export async function genererAudio(texte: string, r: ReglagesPn): Promise<ArrayBuffer> {
  const cle = process.env.ELEVENLABS_API_KEY;
  const voix = r.voice_id || process.env.ELEVENLABS_VOICE_ID;
  if (!cle) throw new Error('ELEVENLABS_API_KEY manquante');
  if (!voix) throw new Error('Voix ElevenLabs non définie (réglages ou ELEVENLABS_VOICE_ID).');
  const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voix}?output_format=mp3_44100_128`, {
    method: 'POST',
    headers: { 'xi-api-key': cle, 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
    body: JSON.stringify({
      text: texte,
      model_id: r.modele_voix || 'eleven_multilingual_v2',
      voice_settings: {
        stability: Number(r.stabilite), similarity_boost: Number(r.similarite),
        style: Number(r.style_voix), use_speaker_boost: true, speed: Number(r.vitesse),
      },
    }),
  });
  if (!res.ok) throw new Error(`ElevenLabs ${res.status} : ${(await res.text()).slice(0, 200)}`);
  return res.arrayBuffer();
}

/* =========================================================
   3. VIDÉO — HeyGen Avatar IV (image + audio)
   ========================================================= */
const HEYGEN = 'https://api.heygen.com';

function cleHeygen() {
  const k = process.env.HEYGEN_API_KEY;
  if (!k) throw new Error('HEYGEN_API_KEY manquante');
  return k;
}

export async function lancerVideo(params: { imageUrl: string; audioUrl: string; titre: string; expressivite: string; motionPrompt: string }): Promise<string> {
  const res = await fetch(`${HEYGEN}/v2/videos`, {
    method: 'POST',
    headers: { 'x-api-key': cleHeygen(), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      image_url: params.imageUrl,
      audio_url: params.audioUrl,
      title: params.titre,
      resolution: '1080p',
      aspect_ratio: '9:16',
      expressiveness: params.expressivite,
      motion_prompt: params.motionPrompt,
    }),
  });
  const texte = await res.text();
  if (!res.ok) throw new Error(`HeyGen ${res.status} : ${texte.slice(0, 300)}`);
  const data = JSON.parse(texte);
  const id = data?.video_id ?? data?.data?.video_id;
  if (!id) throw new Error(`HeyGen : identifiant vidéo absent (${texte.slice(0, 200)})`);
  return String(id);
}

export interface StatutVideo {
  statut: 'pending' | 'processing' | 'completed' | 'failed' | 'waiting' | string;
  videoUrl: string | null;
  dureeSec: number | null;
  erreur: string | null;
}

export async function statutVideo(videoId: string): Promise<StatutVideo> {
  const res = await fetch(`${HEYGEN}/v1/video_status.get?video_id=${encodeURIComponent(videoId)}`, {
    headers: { 'x-api-key': cleHeygen() }, cache: 'no-store',
  });
  const texte = await res.text();
  if (!res.ok) throw new Error(`HeyGen statut ${res.status} : ${texte.slice(0, 200)}`);
  const data = JSON.parse(texte)?.data ?? {};
  const err = data.error;
  return {
    statut: String(data.status ?? 'pending'),
    videoUrl: data.video_url ?? null,
    dureeSec: data.duration ? Math.round(Number(data.duration)) : null,
    erreur: err ? (typeof err === 'string' ? err : err.message ?? err.detail ?? JSON.stringify(err)) : null,
  };
}

/** Solde restant du portefeuille API HeyGen (crédits), null si indisponible. */
export async function creditsHeygen(): Promise<number | null> {
  try {
    const res = await fetch(`${HEYGEN}/v2/user/remaining_quota`, { headers: { 'x-api-key': cleHeygen() }, cache: 'no-store' });
    if (!res.ok) return null;
    const d = (await res.json())?.data;
    const q = d?.remaining_quota ?? d?.api?.remaining_quota;
    return typeof q === 'number' ? q : null;
  } catch { return null; }
}
EOF_PN_FICHIER
echo "  ✓ src/lib/pere-noel/ia.ts"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/pipeline.ts' <<'EOF_PN_FICHIER'
import 'server-only';
import { commandeParId, deposerMedia, lireReglagesPn, majCommande } from './db';
import { genererAudio, genererContenu, lancerVideo, statutVideo } from './ia';
import { emailVideoPrete } from './emails';
import type { CommandePn } from './types';

/**
 * Fait avancer une commande payée d'autant d'étapes que possible :
 *   a_faire → (script) → relecture si activée, sinon → audio → vidéo lancée (statut « video »).
 * La suite (récupération du MP4, email) se fait dans verifierVideo(), quand HeyGen a fini.
 * Chaque étape écrit son résultat en base : en cas d'erreur, on repart de là où on en était.
 */
export async function avancerCommande(id: string, options: { ignorerRelecture?: boolean } = {}): Promise<CommandePn> {
  let c = await commandeParId(id);
  if (!c) throw new Error('Commande introuvable');
  if (c.statut !== 'payee') throw new Error('Commande non payée');
  const r = await lireReglagesPn();

  try {
    // 1. Script
    if (!c.script) {
      const contenu = await genererContenu(c, r);
      await majCommande(c.id, { script: contenu.script, lettre_reponse: contenu.lettre, certificat_mention: contenu.mention, erreur: null,
        gen_statut: r.relecture_script && !options.ignorerRelecture ? 'relecture' : 'audio' });
      c = (await commandeParId(id))!;
      if (c.gen_statut === 'relecture') return c;
    } else if (c.gen_statut === 'relecture' && !options.ignorerRelecture) {
      return c; // en attente de validation admin
    }

    // 2. Audio
    if (!c.audio_url) {
      await majCommande(c.id, { gen_statut: 'audio', erreur: null });
      const mp3 = await genererAudio(c.script!, r);
      const url = await deposerMedia(`audios/${c.reference}.mp3`, mp3, 'audio/mpeg');
      await majCommande(c.id, { audio_url: url });
      c = (await commandeParId(id))!;
    }

    // 3. Vidéo (lancement)
    if (!c.heygen_video_id) {
      if (!r.image_url) throw new Error("Image du Père Noël non définie dans les réglages.");
      const videoId = await lancerVideo({
        imageUrl: r.image_url, audioUrl: c.audio_url!, titre: `${c.reference} ${c.enfant_prenom}`,
        expressivite: r.expressivite, motionPrompt: r.motion_prompt,
      });
      await majCommande(c.id, { heygen_video_id: videoId, gen_statut: 'video', erreur: null });
      c = (await commandeParId(id))!;
    }
    return c;
  } catch (e: any) {
    const message = String(e?.message ?? e).slice(0, 500);
    console.error('[pere-noel] avancerCommande', c.reference, message);
    await majCommande(c.id, { gen_statut: 'erreur', erreur: message });
    return (await commandeParId(id))!;
  }
}

/** Interroge HeyGen ; si la vidéo est prête, la rapatrie dans le stockage et prévient le parent. */
export async function verifierVideo(id: string): Promise<CommandePn> {
  let c = await commandeParId(id);
  if (!c) throw new Error('Commande introuvable');
  if (c.gen_statut !== 'video' || !c.heygen_video_id) return c;

  try {
    const s = await statutVideo(c.heygen_video_id);
    if (s.statut === 'failed') {
      await majCommande(c.id, { gen_statut: 'erreur', erreur: `HeyGen : ${s.erreur ?? 'génération échouée'}`, heygen_video_id: null });
      return (await commandeParId(id))!;
    }
    if (s.statut !== 'completed' || !s.videoUrl) return c;

    const res = await fetch(s.videoUrl);
    if (!res.ok) throw new Error(`Téléchargement HeyGen ${res.status}`);
    const mp4 = await res.arrayBuffer();
    const url = await deposerMedia(`videos/${c.reference}.mp4`, mp4, 'video/mp4');
    await majCommande(c.id, { video_url: url, duree_sec: s.dureeSec, gen_statut: 'terminee', livre_le: new Date().toISOString(), erreur: null });
    c = (await commandeParId(id))!;

    if (!c.email_envoye) {
      const ok = await emailVideoPrete(c);
      if (ok) await majCommande(c.id, { email_envoye: true });
    }
    return (await commandeParId(id))!;
  } catch (e: any) {
    const message = String(e?.message ?? e).slice(0, 500);
    console.error('[pere-noel] verifierVideo', c.reference, message);
    await majCommande(c.id, { erreur: message }); // on reste en « video » pour réessayer au prochain passage
    return (await commandeParId(id))!;
  }
}

/** Passage périodique (cron, ouverture de l'admin) : lance les commandes en attente si auto, vérifie les vidéos en cours. */
export async function traiterFile(limite = 5): Promise<{ lancees: number; verifiees: number }> {
  const { createAdminClient } = await import('@/lib/supabase/admin');
  const db = createAdminClient();
  const r = await lireReglagesPn();
  let lancees = 0, verifiees = 0;

  const { data: enCours } = await db.from('pn_commandes').select('id').eq('statut', 'payee').eq('gen_statut', 'video').limit(limite);
  for (const x of enCours ?? []) { await verifierVideo(x.id); verifiees++; }

  if (r.generation_auto) {
    const { data: aFaire } = await db.from('pn_commandes').select('id').eq('statut', 'payee').eq('gen_statut', 'a_faire').order('paye_le').limit(limite);
    for (const x of aFaire ?? []) { await avancerCommande(x.id); lancees++; }
  }
  return { lancees, verifiees };
}
EOF_PN_FICHIER
echo "  ✓ src/lib/pere-noel/pipeline.ts"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/types.ts' <<'EOF_PN_FICHIER'
export type Sagesse = 'presque' | 'tres_sage' | 'le_plus_sage';
export type TonSecret = 'rigolo' | 'tendre' | 'serieux';
export type StatutPaiement = 'en_attente' | 'payee' | 'echouee' | 'expiree';
export type StatutGeneration = 'a_faire' | 'relecture' | 'audio' | 'video' | 'terminee' | 'erreur';

export interface ReglagesPn {
  id: 1;
  module_actif: boolean;
  commandes_ouvertes: boolean;
  titre: string;
  accroche: string;
  prix_centimes: number;
  delai_texte: string;
  generation_auto: boolean;
  relecture_script: boolean;
  image_url: string | null;
  voice_id: string | null;
  modele_voix: string;
  stabilite: number;
  similarite: number;
  style_voix: number;
  vitesse: number;
  expressivite: 'low' | 'medium' | 'high';
  motion_prompt: string;
  duree_cible_sec: number;
  consignes_script: string;
}

export interface CommandePn {
  id: string;
  created_at: string;
  reference: string;
  token: string;
  test: boolean;
  parent_prenom: string;
  email: string;
  enfant_prenom: string;
  prononciation: string | null;
  age: number | null;
  genre: 'fille' | 'garcon' | null;
  sagesse: Sagesse;
  lettre: string | null;
  cadeaux: string | null;
  fierte: string | null;
  passion: string | null;
  effort: string | null;
  salut: string | null;
  secret: string | null;
  ton_secret: TonSecret;
  montant_centimes: number;
  checkout_id: string | null;
  statut: StatutPaiement;
  transaction_code: string | null;
  paye_le: string | null;
  gen_statut: StatutGeneration;
  script: string | null;
  lettre_reponse: string | null;
  certificat_mention: string | null;
  audio_url: string | null;
  heygen_video_id: string | null;
  video_url: string | null;
  duree_sec: number | null;
  erreur: string | null;
  livre_le: string | null;
  email_envoye: boolean;
}

export interface StatsPn {
  commandes: number;
  ca_centimes: number;
  a_generer: number;
  a_relire: number;
  en_cours: number;
  livrees: number;
  en_erreur: number;
  secondes_video: number;
}

export const LIBELLE_SAGESSE: Record<Sagesse, string> = {
  presque: 'presque sage',
  tres_sage: 'très sage',
  le_plus_sage: 'le plus sage du monde',
};

export const LIBELLE_GEN: Record<StatutGeneration, string> = {
  a_faire: 'À générer',
  relecture: 'Script à relire',
  audio: 'Audio en cours',
  video: 'Vidéo en cours',
  terminee: 'Livrée',
  erreur: 'Erreur',
};

/** Coût HeyGen Avatar IV : 0,05 $ la seconde. Affiché à titre indicatif. */
export const COUT_HEYGEN_USD_PAR_SEC = 0.05;
EOF_PN_FICHIER
echo "  ✓ src/lib/pere-noel/types.ts"
mkdir -p 'supabase'
cat > 'supabase/pere_noel.sql' <<'EOF_PN_FICHIER'
-- =========================================================
-- LE PÈRE NOËL TE RÉPOND — tables du module (préfixe pn_)
-- À exécuter une fois dans l'éditeur SQL de Supabase.
-- Les médias (image du Père Noël, audios, vidéos) vont dans le
-- bucket public « medias » déjà utilisé par le site, dossier pere-noel/.
-- =========================================================

create table if not exists pn_reglages (
  id                 int primary key default 1 check (id = 1),
  module_actif       boolean not null default false,
  commandes_ouvertes boolean not null default false,
  titre              text not null default 'Le Père Noël te répond',
  accroche           text not null default 'Ton enfant écrit au Père Noël. Le Père Noël lui répond en vidéo.',
  prix_centimes      int  not null default 1290,
  delai_texte        text not null default 'sous 48 h',
  generation_auto    boolean not null default false,   -- lancer la génération dès le paiement
  relecture_script   boolean not null default true,    -- l'admin relit le script avant l'audio/vidéo
  image_url          text,                              -- image du Père Noël (portrait 9:16)
  voice_id           text,                              -- voix ElevenLabs
  modele_voix        text not null default 'eleven_multilingual_v2',
  stabilite          numeric not null default 0.45,
  similarite         numeric not null default 0.75,
  style_voix         numeric not null default 0.30,
  vitesse            numeric not null default 0.92,
  expressivite       text not null default 'medium',   -- low | medium | high (HeyGen)
  motion_prompt      text not null default 'Le Père Noël parle chaleureusement face caméra, légers mouvements de tête, sourire, clignements naturels, les mains restent hors du cadre.',
  duree_cible_sec    int not null default 75,
  consignes_script   text not null default '',
  updated_at         timestamptz not null default now()
);
insert into pn_reglages (id) values (1) on conflict (id) do nothing;

create table if not exists pn_commandes (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  reference         text unique not null,
  token             text unique not null default encode(gen_random_bytes(16), 'hex'),
  test              boolean not null default false,

  -- parent
  parent_prenom     text not null default '',
  email             text not null,

  -- enfant
  enfant_prenom     text not null,
  prononciation     text,
  age               int,
  genre             text,                 -- fille | garcon | null
  sagesse           text not null default 'tres_sage',   -- presque | tres_sage | le_plus_sage
  lettre            text,
  cadeaux           text,
  fierte            text,
  passion           text,
  effort            text,
  salut             text,
  secret            text,
  ton_secret        text not null default 'rigolo',      -- rigolo | tendre | serieux

  -- paiement
  montant_centimes  int not null default 0,
  checkout_id       text,
  statut            text not null default 'en_attente',  -- en_attente | payee | echouee | expiree
  transaction_code  text,
  paye_le           timestamptz,

  -- génération
  gen_statut        text not null default 'a_faire',     -- a_faire | relecture | audio | video | terminee | erreur
  script            text,
  lettre_reponse    text,
  certificat_mention text,
  audio_url         text,
  heygen_video_id   text,
  video_url         text,
  duree_sec         int,
  erreur            text,
  livre_le          timestamptz,
  email_envoye      boolean not null default false
);
create index if not exists pn_commandes_statut_idx on pn_commandes (statut, gen_statut);
create index if not exists pn_commandes_checkout_idx on pn_commandes (checkout_id);

-- Sécurité : tout passe par le serveur (service role). Lecture publique des réglages uniquement.
alter table pn_reglages enable row level security;
alter table pn_commandes enable row level security;
drop policy if exists pn_reglages_lecture on pn_reglages;
create policy pn_reglages_lecture on pn_reglages for select using (true);

-- Statistiques pour le tableau de bord
create or replace view pn_stats as
select
  count(*) filter (where statut = 'payee' and not test)                              as commandes,
  coalesce(sum(montant_centimes) filter (where statut = 'payee' and not test), 0)   as ca_centimes,
  count(*) filter (where statut = 'payee' and gen_statut = 'a_faire')                as a_generer,
  count(*) filter (where statut = 'payee' and gen_statut = 'relecture')              as a_relire,
  count(*) filter (where statut = 'payee' and gen_statut in ('audio','video'))        as en_cours,
  count(*) filter (where statut = 'payee' and gen_statut = 'terminee')               as livrees,
  count(*) filter (where statut = 'payee' and gen_statut = 'erreur')                 as en_erreur,
  coalesce(sum(duree_sec) filter (where gen_statut = 'terminee'), 0)                 as secondes_video
from pn_commandes;
EOF_PN_FICHIER
echo "  ✓ supabase/pere_noel.sql"
cat > 'vercel.json' <<'EOF_PN_FICHIER'
{
  "crons": [
    { "path": "/api/pere-noel/cron", "schedule": "0 * * * *" }
  ]
}
EOF_PN_FICHIER
echo "  ✓ vercel.json"

echo
echo "Terminé : 36 fichiers écrits."
echo "Étapes suivantes :"
echo "  1. Exécuter supabase/pere_noel.sql dans l'éditeur SQL Supabase"
echo "  2. Ajouter les variables Vercel : ANTHROPIC_API_KEY ELEVENLABS_API_KEY ELEVENLABS_VOICE_ID HEYGEN_API_KEY CRON_SECRET"
echo "  3. git add -A && git commit -m 'Module Le Père Noël te répond' && git push && vercel --prod"
