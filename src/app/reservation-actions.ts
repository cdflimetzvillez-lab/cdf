'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout, genererReference } from '@/lib/sumup';
import { billetHtml, billetTexte, alerteReservationHtml } from '@/lib/emails';

export type EtatResa = { erreur?: string } | null;

/** Champs de l'événement rapatriés avec la réservation, pour l'email. */
const CHAMPS_EVT =
  '*, evenements(titre, slug, date_debut, date_fin, lieu, adresse, heure_debut, heure_fin, couleur)';

/* =========================================================
   PUBLIC — créer une réservation et partir en paiement
   ========================================================= */
export async function reserver(_prev: EtatResa, fd: FormData): Promise<EtatResa> {
  const evenementId = String(fd.get('evenement_id') ?? '');
  const nom         = String(fd.get('nom') ?? '').trim();
  const email       = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone   = String(fd.get('telephone') ?? '').trim();
  const commentaire = String(fd.get('commentaire') ?? '').trim();
  // lignes de tarif : id + quantité, en parallèle
  const tarifIds  = fd.getAll('tarif_id').map(String);
  const tarifQtes = fd.getAll('tarif_qte').map((v) => Number(v) || 0);
  const places    = tarifQtes.reduce((s, q) => s + q, 0);

  if (!nom || nom.length < 2) return { erreur: 'Merci d\u2019indiquer votre nom.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse email invalide.' };
  if (telephone.replace(/[\s.\-()]/g, '').length < 10)
    return { erreur: 'Merci d\u2019indiquer un numéro de téléphone valide.' };
  if (places < 1) return { erreur: 'Choisissez au moins une place.' };

  const db = createAdminClient();

  const { data: evt } = await db
    .from('evenements')
    .select('id, titre, slug, prix_centimes, places_max, places_par_reservation, billetterie_active, cloture_reservations')
    .eq('id', evenementId)
    .maybeSingle();

  if (!evt || !evt.billetterie_active) return { erreur: 'La billetterie est fermée pour cet événement.' };
  if (places > evt.places_par_reservation)
    return { erreur: `Maximum ${evt.places_par_reservation} places par réservation.` };

  if (evt.cloture_reservations && new Date(evt.cloture_reservations) < new Date())
    return { erreur: 'Les réservations sont closes pour cet événement.' };

  // Jauge
  if (evt.places_max !== null) {
    const { data: restantes } = await db.rpc('places_restantes', { evt_id: evt.id });
    if (typeof restantes === 'number' && restantes < places) {
      return {
        erreur: restantes === 0
          ? 'Complet — il ne reste plus de place.'
          : `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}.`,
      };
    }
  }

  // Prix recalculés côté serveur : jamais de confiance au formulaire.
  const { data: grille } = await db
    .from('tarifs')
    .select('id, libelle, prix_centimes')
    .eq('evenement_id', evt.id);

  const lignes: { libelle: string; prix_centimes: number; quantite: number }[] = [];
  let montant = 0;

  tarifIds.forEach((id, i) => {
    const q = tarifQtes[i] ?? 0;
    if (q <= 0) return;
    const t = (grille ?? []).find((x) => x.id === id);
    // « defaut » = événement sans grille, on prend le prix unique
    const libelle = t?.libelle ?? 'Place';
    const prix = t ? t.prix_centimes : evt.prix_centimes;
    lignes.push({ libelle, prix_centimes: prix, quantite: q });
    montant += prix * q;
  });

  if (lignes.length === 0) return { erreur: 'Choisissez au moins une place.' };

  const reference = genererReference();

  // 1. Réservation en attente
  const { data: resa, error: errResa } = await db
    .from('reservations')
    .insert({
      evenement_id: evt.id,
      nom, email,
      telephone: telephone || null,
      commentaire: commentaire || null,
      places,
      montant_centimes: montant,
      reference,
      statut: 'en_attente',
    })
    .select('id')
    .single();

  if (errResa || !resa) {
    console.error('[reserver] insert', errResa);
    return { erreur: 'Impossible de créer la réservation. Réessayez dans un instant.' };
  }

  // 1 bis. Détail des tarifs
  await db.from('reservation_lignes').insert(
    lignes.map((l) => ({ reservation_id: resa.id, ...l }))
  );

  // 2. Checkout SumUp
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  let urlPaiement: string | undefined;

  try {
    const checkout = await creerCheckout({
      reference,
      montantCentimes: montant,
      description: `${reference} · ${nom} · ${evt.titre} · ${places} place${places > 1 ? 's' : ''}`,
      emailClient: email,
      urlRetour: `${base}/evenements/${evt.slug}/reservation?ref=${reference}`,
    });

    await db.from('reservations')
      .update({ checkout_id: checkout.id })
      .eq('id', resa.id);

    urlPaiement = checkout.hosted_checkout_url;
  } catch (e) {
    console.error('[reserver] SumUp', e);
    await db.from('reservations')
      .update({ statut: 'echouee' })
      .eq('id', resa.id);
    return { erreur: 'Le service de paiement est indisponible. Réessayez plus tard.' };
  }

  if (!urlPaiement) return { erreur: 'Le paiement n\u2019a pas pu être initialisé.' };

  redirect(urlPaiement);
}

/* =========================================================
   Vérification au retour de paiement
   ========================================================= */
export async function verifierPaiement(reference: string) {
  const db = createAdminClient();

  const { data: resa } = await db
    .from('reservations')
    .select(CHAMPS_EVT)
    .eq('reference', reference)
    .maybeSingle();

  if (!resa) return null;
  if (resa.statut === 'payee' || !resa.checkout_id) return resa;

  try {
    const checkout = await lireCheckout(resa.checkout_id);

    const correspondance: Record<string, string> = {
      PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente',
    };
    const nouveau = correspondance[checkout.status] ?? 'en_attente';

    if (nouveau !== resa.statut) {
      const { data: maj } = await db
        .from('reservations')
        .update({
          statut: nouveau,
          transaction_code: checkout.transaction_code
            ?? checkout.transactions?.[0]?.transaction_code
            ?? null,
          paye_le: nouveau === 'payee' ? new Date().toISOString() : null,
        })
        .eq('id', resa.id)
        .select(CHAMPS_EVT)
        .single();

      if (nouveau === 'payee') await envoyerBillet(maj);
      return maj ?? resa;
    }
  } catch (e) {
    console.error('[verifierPaiement]', e);
  }

  return resa;
}

/* =========================================================
   Emails — billet au client et alerte au comité.
   Silencieux si RESEND_API_KEY n'est pas configurée :
   la réservation reste valide, seul l'envoi est désactivé.
   ========================================================= */
export async function envoyerBillet(resa: any, alerterComite = true) {
  if (!process.env.RESEND_API_KEY || !resa) return;

  const evt = resa.evenements ?? {};
  const from = process.env.RESEND_FROM_EMAIL
    ?? 'Comité des Fêtes de Limetz-Villez <billetterie@cdf-limetzvillez.fr>';
  const urlSite = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://cdf-limetzvillez.fr';

  const donnees = {
    nom: resa.nom,
    places: resa.places,
    montant_centimes: resa.montant_centimes,
    code_billet: resa.code_billet,
    reference: resa.reference,
    commentaire: resa.commentaire,
    evenement: {
      titre: evt.titre ?? 'Comité des Fêtes',
      date_debut: evt.date_debut,
      date_fin: evt.date_fin,
      heure_debut: evt.heure_debut,
      heure_fin: evt.heure_fin,
      lieu: evt.lieu,
      adresse: evt.adresse,
      couleur: evt.couleur,
      slug: evt.slug,
    },
  };

  const envoyer = (corps: Record<string, unknown>) =>
    fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(corps),
    });

  // --- billet au client (les réservations saisies à la main peuvent ne pas avoir d'e-mail) ---
  if (resa.email) {
    try {
      const r = await envoyer({
        from,
        to: [resa.email],
        reply_to: process.env.CONTACT_EMAIL,
        subject: `Votre billet — ${donnees.evenement.titre}`,
        html: billetHtml(donnees, urlSite),
        text: billetTexte(donnees),
      });
      if (!r.ok) console.error('[envoyerBillet] client', r.status, await r.text());
    } catch (e) {
      console.error('[envoyerBillet] client', e);
    }
  }

  // --- alerte au comité ---
  if (alerterComite && process.env.CONTACT_EMAIL) {
    try {
      const r = await envoyer({
        from,
        to: [process.env.CONTACT_EMAIL],
        reply_to: resa.email ?? undefined,
        subject: `Réservation : ${resa.nom} — ${donnees.evenement.titre}`,
        html: alerteReservationHtml(donnees),
      });
      if (!r.ok) console.error('[envoyerBillet] comité', r.status, await r.text());
    } catch (e) {
      console.error('[envoyerBillet] comité', e);
    }
  }
}

/* =========================================================
   ADMIN
   ========================================================= */
export async function marquerScanne(id: string) {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return;
  await supabase.from('reservations')
    .update({ scanne_le: new Date().toISOString() })
    .eq('id', id);
  revalidatePath('/admin/reservations');
}

export async function changerStatutResa(id: string, statut: string): Promise<{ erreur?: string } | void> {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return;

  const maj: Record<string, unknown> = { statut };
  if (statut === 'payee') {
    const { data: resa } = await supabase
      .from('reservations').select('paye_le, checkout_id').eq('id', id).maybeSingle();
    if (resa && !resa.paye_le) {
      // Sans paiement en ligne, le mode (espèces ou chèque) doit être indiqué.
      if (!resa.checkout_id) {
        return { erreur: 'Paiement hors ligne : utilise le bouton « Encaisser » pour indiquer espèces ou chèque.' };
      }
      maj.paye_le = new Date().toISOString();
    }
  }

  const { error } = await supabase.from('reservations').update(maj).eq('id', id);
  if (error) return { erreur: error.message };
  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
}

export async function supprimerReservation(id: string) {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return;
  await supabase.from('reservations').delete().eq('id', id);
  revalidatePath('/admin/reservations');
}

/** Admin : force une vérification auprès de SumUp pour une réservation (ou toutes celles en attente). */
export async function verifierSumUpAdmin(reference?: string): Promise<{ verifiees: number; changees: number; erreur?: string }> {
  const { supabase, isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { verifiees: 0, changees: 0, erreur: 'Accès refusé.' };
  let refs: string[] = [];
  if (reference) refs = [reference];
  else {
    const { data } = await supabase.from('reservations').select('reference').eq('statut', 'en_attente').not('checkout_id', 'is', null);
    refs = (data ?? []).map((r) => r.reference);
  }
  let changees = 0;
  for (const ref of refs) {
    const db = createAdminClient();
    const { data: avant } = await db.from('reservations').select('statut').eq('reference', ref).maybeSingle();
    const apres = await verifierPaiement(ref);
    if (apres && avant && apres.statut !== avant.statut) changees++;
  }
  revalidatePath('/admin/reservations');
  return { verifiees: refs.length, changees };
}

/* =========================================================
   ADMIN — réservation saisie à la main, paiement hors ligne
   ========================================================= */
export type EtatManuel = { ok?: string; erreur?: string } | null;

const MODES_HORS_LIGNE = ['especes', 'cheque'];

/** « 25 », « 25,5 » ou « 25.50 » -> centimes. null si la saisie est invalide. */
function centimes(saisie: string): number | null {
  const propre = saisie.replace(/[\s\u00a0\u202f€]/g, '').replace(',', '.');
  if (!/^\d+(\.\d{1,2})?$/.test(propre)) return null;
  return Math.round(parseFloat(propre) * 100);
}

/** Explique l'erreur quand les colonnes de paiement n'ont pas encore été créées. */
function erreurBase(message: string): string {
  return /mode_paiement|paiement_ref|saisie_par|exposant/.test(message)
    ? 'La base n\u2019est pas à jour : exécute supabase/comptabilite.sql dans Supabase, puis réessaie.'
    : message;
}

/**
 * Ajoute un participant ou un exposant depuis l'admin,
 * payé en espèces, par chèque, ou pas encore payé.
 */
export async function ajouterReservationManuelle(_prev: EtatManuel, fd: FormData): Promise<EtatManuel> {
  const { supabase, isAdmin, user } = await requireAdmin('reservations');
  if (!isAdmin || !user) return { erreur: 'Accès refusé.' };

  const evenementId = String(fd.get('evenement_id') ?? '');
  const nom         = String(fd.get('nom') ?? '').trim();
  const email       = String(fd.get('email') ?? '').trim().toLowerCase();
  const telephone   = String(fd.get('telephone') ?? '').trim();
  const commentaire = String(fd.get('commentaire') ?? '').trim();
  const exposant    = fd.get('type') === 'exposant';
  const paiement    = String(fd.get('paiement') ?? 'attente'); // especes | cheque | attente
  const paiementRef = String(fd.get('paiement_ref') ?? '').trim();
  const montantTxt  = String(fd.get('montant') ?? '').trim();
  const tarifIds    = fd.getAll('tarif_id').map(String);
  const tarifQtes   = fd.getAll('tarif_qte').map((v) => Math.max(0, Math.floor(Number(v) || 0)));
  const quantite    = tarifQtes.reduce((s, q) => s + q, 0);
  // Un exposant compte pour une seule présence au pointage, quelles que soient ses formules.
  const places      = exposant ? 1 : quantite;
  const rien        = exposant ? 'Choisis au moins une formule.' : 'Indique au moins une place.';

  if (nom.length < 2) return { erreur: 'Le nom est obligatoire.' };
  if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse e-mail invalide.' };
  if (quantite < 1) return { erreur: rien };
  if (paiement !== 'attente' && !MODES_HORS_LIGNE.includes(paiement)) return { erreur: 'Mode de paiement invalide.' };

  const db = createAdminClient();

  const { data: evt } = await db
    .from('evenements').select('id, titre, prix_centimes, places_max').eq('id', evenementId).maybeSingle();
  if (!evt) return { erreur: 'Événement introuvable.' };

  // Jauge : bloquante, sauf dépassement demandé explicitement. Elle ne concerne pas les exposants.
  if (!exposant && evt.places_max !== null && fd.get('depasser') !== 'on') {
    const { data: restantes } = await db.rpc('places_restantes', { evt_id: evt.id });
    if (typeof restantes === 'number' && restantes < places) {
      return {
        erreur: `Il ne reste que ${restantes} place${restantes > 1 ? 's' : ''}. Coche « Autoriser le dépassement de la jauge » pour l\u2019ajouter quand même.`,
      };
    }
  }

  // Participants : grille de tarifs de l'événement. Exposants : formules exposants.
  const { data: grille } = await db
    .from(exposant ? 'formules_exposants' : 'tarifs')
    .select('id, libelle, prix_centimes')
    .eq('evenement_id', evt.id);
  const lignes: { libelle: string; prix_centimes: number; quantite: number }[] = [];
  let montant = 0;
  tarifIds.forEach((id, i) => {
    const q = tarifQtes[i] ?? 0;
    if (q <= 0) return;
    const t = (grille ?? []).find((x) => x.id === id);
    // Sans grille : prix unique de l'événement, ou emplacement à prix libre pour un exposant.
    const prix = t ? t.prix_centimes : exposant ? 0 : evt.prix_centimes ?? 0;
    lignes.push({ libelle: t?.libelle ?? (exposant ? 'Emplacement' : 'Place'), prix_centimes: prix, quantite: q });
    montant += prix * q;
  });
  if (lignes.length === 0) return { erreur: rien };

  // Montant encaissé : celui du formulaire s'il a été modifié (tarif spécial, invitation à 0).
  if (montantTxt !== '') {
    const saisi = centimes(montantTxt);
    if (saisi === null) return { erreur: 'Montant invalide.' };
    montant = saisi;
  }

  const { data: moi } = await supabase.from('admins').select('nom').eq('id', user.id).maybeSingle();
  const paye = paiement !== 'attente';

  const { data: resa, error } = await db
    .from('reservations')
    .insert({
      evenement_id: evt.id,
      nom,
      email: email || null,
      telephone: telephone || null,
      commentaire: commentaire || null,
      places,
      montant_centimes: montant,
      reference: genererReference(),
      statut: paye ? 'payee' : 'en_attente',
      paye_le: paye ? new Date().toISOString() : null,
      mode_paiement: paye ? paiement : null,
      paiement_ref: paye && paiementRef ? paiementRef : null,
      saisie_par: moi?.nom ?? user.email ?? 'Admin',
      // La colonne n'est envoyée que pour un exposant : les participants ne dépendent pas d'elle.
      ...(exposant ? { exposant: true } : {}),
    })
    .select(CHAMPS_EVT)
    .single();

  if (error || !resa) {
    console.error('[ajouterReservationManuelle]', error);
    return { erreur: erreurBase(error?.message ?? 'Impossible de créer la réservation.') };
  }

  await db.from('reservation_lignes').insert(lignes.map((l) => ({ reservation_id: resa.id, ...l })));

  // Le billet d'entrée n'a pas de sens pour un exposant.
  if (!exposant && paye && email && fd.get('envoyer_billet') === 'on') await envoyerBillet(resa, false);

  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
  const quoi = exposant ? 'exposant ajouté' : `ajouté, ${places} place${places > 1 ? 's' : ''}`;
  return {
    ok: `${nom} : ${quoi}, code ${resa.code_billet}. ${paye ? 'Paiement enregistré.' : 'Paiement en attente.'}`,
  };
}

/** Enregistre le paiement en espèces ou par chèque d'une réservation non payée. */
export async function encaisserReservation(id: string, mode: string, ref?: string): Promise<{ ok?: boolean; erreur?: string }> {
  const { isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  if (!MODES_HORS_LIGNE.includes(mode)) return { erreur: 'Mode de paiement invalide.' };

  const db = createAdminClient();
  const { data: resa } = await db.from('reservations').select('id, statut').eq('id', id).maybeSingle();
  if (!resa) return { erreur: 'Réservation introuvable.' };
  if (resa.statut === 'payee') return { erreur: 'Cette réservation est déjà payée.' };

  const { data: maj, error } = await db
    .from('reservations')
    .update({
      statut: 'payee',
      paye_le: new Date().toISOString(),
      mode_paiement: mode,
      paiement_ref: ref?.trim() || null,
    })
    .eq('id', id)
    .select(CHAMPS_EVT)
    .single();
  if (error) return { erreur: erreurBase(error.message) };

  if (maj?.email && !maj.exposant) await envoyerBillet(maj, false);

  revalidatePath('/admin/reservations');
  revalidatePath('/admin/tresorerie');
  return { ok: true };
}

/* =========================================================
   ADMIN — formules proposées aux exposants d'un événement
   ========================================================= */
export async function ajouterFormuleExposant(evenementId: string, libelle: string, prix: string): Promise<{ ok?: boolean; erreur?: string }> {
  const { isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const nom = libelle.trim();
  const prixCentimes = centimes(prix.trim() || '0');
  if (!evenementId) return { erreur: 'Choisis un événement.' };
  if (nom.length < 2) return { erreur: 'Le libellé de la formule est obligatoire.' };
  if (prixCentimes === null) return { erreur: 'Prix invalide.' };

  const db = createAdminClient();
  const { count } = await db
    .from('formules_exposants').select('id', { count: 'exact', head: true }).eq('evenement_id', evenementId);
  const { error } = await db.from('formules_exposants').insert({
    evenement_id: evenementId, libelle: nom, prix_centimes: prixCentimes, position: (count ?? 0) + 1,
  });
  if (error) {
    return {
      erreur: /formules_exposants/.test(error.message)
        ? 'La base n\u2019est pas à jour : exécute supabase/comptabilite.sql dans Supabase, puis réessaie.'
        : error.message,
    };
  }
  revalidatePath('/admin/reservations');
  return { ok: true };
}

/** Retire une formule. Les réservations déjà saisies gardent leur détail. */
export async function supprimerFormuleExposant(id: string): Promise<{ ok?: boolean; erreur?: string }> {
  const { isAdmin } = await requireAdmin('reservations');
  if (!isAdmin) return { erreur: 'Accès refusé.' };
  const { error } = await createAdminClient().from('formules_exposants').delete().eq('id', id);
  if (error) return { erreur: error.message };
  revalidatePath('/admin/reservations');
  return { ok: true };
}
