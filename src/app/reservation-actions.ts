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
export async function envoyerBillet(resa: any) {
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

  // --- billet au client ---
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

  // --- alerte au comité ---
  if (process.env.CONTACT_EMAIL) {
    try {
      const r = await envoyer({
        from,
        to: [process.env.CONTACT_EMAIL],
        reply_to: resa.email,
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
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('reservations')
    .update({ scanne_le: new Date().toISOString() })
    .eq('id', id);
  revalidatePath('/admin/reservations');
}

export async function changerStatutResa(id: string, statut: string) {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('reservations').update({ statut }).eq('id', id);
  revalidatePath('/admin/reservations');
}

export async function supprimerReservation(id: string) {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return;
  await supabase.from('reservations').delete().eq('id', id);
  revalidatePath('/admin/reservations');
}
