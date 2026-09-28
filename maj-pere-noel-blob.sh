#!/usr/bin/env bash
# Mise à jour : vidéos du Père Noël stockées sur Vercel Blob (+ HeyGen 720p par défaut).
# À exécuter à la racine du projet :  bash maj-pere-noel-blob.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
cat > 'package.json' <<'EOF_PN_FICHIER'
{
  "name": "comite-fetes-limetz-villez",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@supabase/ssr": "^0.5.2",
    "@supabase/supabase-js": "^2.45.4",
    "@vercel/blob": "^2.8.0",
    "next": "^15.5.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/node": "^22.9.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "typescript": "^5.6.3"
  }
}
EOF_PN_FICHIER
echo "  ✓ package.json"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/db.ts' <<'EOF_PN_FICHIER'
import 'server-only';
import { put } from '@vercel/blob';
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

/**
 * Vidéos : Vercel Blob (jusqu'à 5 Go par fichier) si BLOB_READ_WRITE_TOKEN est défini,
 * sinon le bucket Supabase (plafonné à 50 Mo sur le plan gratuit).
 */
export async function deposerVideo(chemin: string, contenu: ArrayBuffer): Promise<string> {
  if (process.env.BLOB_READ_WRITE_TOKEN) {
    const { url } = await put(`pere-noel/${chemin}`, contenu, {
      access: 'public', contentType: 'video/mp4', addRandomSuffix: false, allowOverwrite: true, multipart: true,
    });
    return url;
  }
  return deposerMedia(chemin, contenu, 'video/mp4');
}

export function referencePn() {
  const bloc = () => Math.random().toString(36).slice(2, 8).toUpperCase();
  return `PN-${bloc()}-${bloc().slice(0, 4)}`;
}
EOF_PN_FICHIER
echo "  ✓ src/lib/pere-noel/db.ts"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/pipeline.ts' <<'EOF_PN_FICHIER'
import 'server-only';
import { commandeParId, deposerMedia, deposerVideo, lireReglagesPn, majCommande } from './db';
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
    const url = await deposerVideo(`videos/${c.reference}.mp4`, mp4);
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
      resolution: process.env.HEYGEN_RESOLUTION === '1080p' ? '1080p' : '720p',
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
  const urlTelechargement = !c.video_url ? '#'
    : c.video_url.includes('vercel-storage.com') ? `${c.video_url}?download=1`
    : `${c.video_url}${c.video_url.includes('?') ? '&' : '?'}download=${encodeURIComponent(nomFichier)}`;
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

npm install
git add -A && git commit -m "Père Noël : vidéos stockées sur Vercel Blob, HeyGen 720p" && git push
vercel --prod
