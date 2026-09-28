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
