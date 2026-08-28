'use server';

import { revalidatePath } from 'next/cache';
import { createClient, requireAdmin } from '@/lib/supabase/server';

export type ActionState = { ok?: string; error?: string } | null;

/* ============ PUBLIC : envoi d'une demande ============ */
export async function envoyerDemande(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const nom = String(fd.get('nom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim();
  const type = String(fd.get('type') ?? 'autre');
  const message = String(fd.get('message') ?? '').trim();
  const telephone = String(fd.get('telephone') ?? '').trim();
  const evenement_id = (fd.get('evenement_id') as string) || null;

  if (!nom || !email) return { error: 'Le nom et l\'email sont obligatoires.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { error: 'Email invalide.' };

  const supabase = await createClient();
  const { error } = await supabase.from('demandes').insert({
    nom, email, type, message: message || null,
    telephone: telephone || null, evenement_id,
  });
  if (error) return { error: "L'envoi a échoué. Réessayez ou écrivez-nous directement." };

  // Notification email (optionnelle : nécessite RESEND_API_KEY)
  if (process.env.RESEND_API_KEY && process.env.CONTACT_EMAIL) {
    try {
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: 'Site du Comité <noreply@comitedesfetes-limetzvillez.fr>',
          to: [process.env.CONTACT_EMAIL],
          subject: `Nouvelle demande — ${type}`,
          text: `${nom} (${email}${telephone ? ' / ' + telephone : ''})\nType : ${type}\n\n${message}`,
        }),
      });
    } catch { /* la demande est enregistrée, l'email est un bonus */ }
  }

  return { ok: 'Message envoyé. Le comité vous répond sous quelques jours.' };
}

/* ============ ADMIN : réglages du site ============ */
export async function majReglages(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return { error: 'Accès refusé.' };

  const champs = ['hero_kicker','hero_titre_1','hero_titre_accent','hero_titre_2','hero_texte',
    'hero_couleur','logo_url','logo_blanc_url','email_contact','facebook_url','adresse',
    'asso_titre','asso_texte','benevoles_titre','benevoles_texte'] as const;

  const payload: Record<string, string | null> = {};
  champs.forEach((c) => {
    const v = String(fd.get(c) ?? '').trim();
    payload[c] = v === '' ? null : v;
  });

  const { error } = await supabase.from('site_settings').update(payload).eq('id', 1);
  if (error) return { error: error.message };

  revalidatePath('/'); revalidatePath('/admin/parametres');
  return { ok: 'Réglages enregistrés.' };
}

/* ============ ADMIN : chiffres clés ============ */
export async function majStats(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return { error: 'Accès refusé.' };

  const valeurs = fd.getAll('stat_valeur').map(String);
  const libelles = fd.getAll('stat_libelle').map(String);

  await supabase.from('stats').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  const lignes = valeurs
    .map((v, i) => ({ valeur: v.trim(), libelle: (libelles[i] ?? '').trim(), position: i + 1 }))
    .filter((l) => l.valeur && l.libelle);

  if (lignes.length) {
    const { error } = await supabase.from('stats').insert(lignes);
    if (error) return { error: error.message };
  }
  revalidatePath('/'); revalidatePath('/admin/association');
  return { ok: 'Chiffres clés mis à jour.' };
}

/* ============ ADMIN : événement ============ */
export async function enregistrerEvenement(_prev: ActionState, fd: FormData): Promise<ActionState> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return { error: 'Accès refusé.' };

  const id = String(fd.get('id') ?? '');
  const titre = String(fd.get('titre') ?? '').trim();
  if (!titre) return { error: 'Le titre est obligatoire.' };

  const slug = (String(fd.get('slug') ?? '').trim() || titre)
    .toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

  const data = {
    slug, titre,
    sous_titre: String(fd.get('sous_titre') ?? '').trim() || null,
    chapo: String(fd.get('chapo') ?? '').trim() || null,
    description: String(fd.get('description') ?? '').trim() || null,
    couleur: String(fd.get('couleur') ?? '#FF3D7F'),
    couleur_sombre: String(fd.get('couleur_sombre') ?? '#C42A5F'),
    date_debut: String(fd.get('date_debut') ?? ''),
    date_fin: String(fd.get('date_fin') ?? '') || null,
    heure_debut: String(fd.get('heure_debut') ?? '').trim() || null,
    heure_fin: String(fd.get('heure_fin') ?? '').trim() || null,
    lieu: String(fd.get('lieu') ?? '').trim() || null,
    adresse: String(fd.get('adresse') ?? '').trim() || null,
    tarif: String(fd.get('tarif') ?? 'Entrée libre'),
    lien_reservation: String(fd.get('lien_reservation') ?? '').trim() || null,
    libelle_reservation: String(fd.get('libelle_reservation') ?? '').trim() || 'Réserver',
    billetterie_active: fd.get('billetterie_active') === 'on',
    prix_centimes: Math.round(Number(fd.get('prix_euros') ?? 0) * 100),
    places_max: fd.get('places_max') ? Number(fd.get('places_max')) : null,
    places_par_reservation: Number(fd.get('places_par_reservation') ?? 10),
    cloture_reservations: String(fd.get('cloture_reservations') ?? '') || null,
    saison: String(fd.get('saison') ?? 'ete'),
    image_url: String(fd.get('image_url') ?? '').trim() || null,
    publie: fd.get('publie') === 'on',
    position: Number(fd.get('position') ?? 0),
  };

  let evenementId = id;
  if (id) {
    const { error } = await supabase.from('evenements').update(data).eq('id', id);
    if (error) return { error: error.message };
  } else {
    const { data: cree, error } = await supabase.from('evenements').insert(data).select('id').single();
    if (error) return { error: error.message };
    evenementId = cree.id;
  }

  // --- créneaux ---
  await supabase.from('creneaux').delete().eq('evenement_id', evenementId);
  const heures = fd.getAll('cr_heure').map(String);
  const ctitres = fd.getAll('cr_titre').map(String);
  const cdesc = fd.getAll('cr_desc').map(String);
  const cscene = fd.getAll('cr_scene').map(String);
  const creneaux = heures
    .map((h, i) => ({
      evenement_id: evenementId, heure: h.trim(), titre: (ctitres[i] ?? '').trim(),
      description: (cdesc[i] ?? '').trim() || null, scene: (cscene[i] ?? '').trim() || null,
      position: i + 1,
    }))
    .filter((c) => c.heure && c.titre);
  if (creneaux.length) await supabase.from('creneaux').insert(creneaux);

  // --- blocs d'infos ---
  await supabase.from('infos').delete().eq('evenement_id', evenementId);
  const iTitres = fd.getAll('inf_titre').map(String);
  const iLignes = fd.getAll('inf_lignes').map(String);
  const infos = iTitres
    .map((t, i) => ({
      evenement_id: evenementId, titre: t.trim(),
      lignes: (iLignes[i] ?? '').split('\n').map((l) => l.trim()).filter(Boolean),
      position: i + 1,
    }))
    .filter((b) => b.titre && b.lignes.length);
  if (infos.length) await supabase.from('infos').insert(infos);

  // --- FAQ ---
  await supabase.from('faq').delete().eq('evenement_id', evenementId);
  const qs = fd.getAll('faq_q').map(String);
  const rs = fd.getAll('faq_r').map(String);
  const faq = qs
    .map((q, i) => ({
      evenement_id: evenementId, question: q.trim(),
      reponse: (rs[i] ?? '').trim(), position: i + 1,
    }))
    .filter((f) => f.question && f.reponse);
  if (faq.length) await supabase.from('faq').insert(faq);

  // --- tarifs ---
  await supabase.from('tarifs').delete().eq('evenement_id', evenementId);
  const tLibelles = fd.getAll('tarif_libelle').map(String);
  const tPrix     = fd.getAll('tarif_prix').map(String);
  const tDescr    = fd.getAll('tarif_description').map(String);
  const tarifs = tLibelles
    .map((libelle, i) => ({
      evenement_id: evenementId,
      libelle: libelle.trim(),
      description: (tDescr[i] ?? '').trim() || null,
      prix_centimes: Math.round(Number(tPrix[i] ?? 0) * 100),
      position: i + 1,
    }))
    .filter((t) => t.libelle);
  if (tarifs.length) await supabase.from('tarifs').insert(tarifs);

  // --- documents (affiches, menus, photos) ---
  await supabase.from('documents').delete().eq('evenement_id', evenementId);
  const dUrls     = fd.getAll('doc_url').map(String);
  const dTitres   = fd.getAll('doc_titre').map(String);
  const dLegendes = fd.getAll('doc_legende').map(String);
  const dTypes    = fd.getAll('doc_type').map(String);
  const documents = dUrls
    .map((url, i) => ({
      evenement_id: evenementId,
      url,
      titre: (dTitres[i] ?? '').trim() || null,
      legende: (dLegendes[i] ?? '').trim() || null,
      type: dTypes[i] === 'pdf' ? 'pdf' : 'image',
      position: i + 1,
    }))
    .filter((d) => d.url);
  if (documents.length) await supabase.from('documents').insert(documents);

  revalidatePath('/');
  revalidatePath(`/evenements/${slug}`);
  revalidatePath('/admin/evenements');
  return { ok: 'Événement enregistré.' };
}

export async function supprimerEvenement(id: string) {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('evenements').delete().eq('id', id);
  revalidatePath('/'); revalidatePath('/admin/evenements');
}

export async function basculerPublication(id: string, publie: boolean) {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('evenements').update({ publie }).eq('id', id);
  revalidatePath('/'); revalidatePath('/admin/evenements');
}

/* ============ ADMIN : demandes ============ */
export async function changerStatutDemande(id: string, statut: string) {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('demandes').update({ statut }).eq('id', id);
  revalidatePath('/admin/demandes');
}

export async function supprimerDemande(id: string) {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('demandes').delete().eq('id', id);
  revalidatePath('/admin/demandes');
}
