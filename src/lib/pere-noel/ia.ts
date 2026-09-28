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
