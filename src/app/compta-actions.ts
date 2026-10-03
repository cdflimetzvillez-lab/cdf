'use server';

import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';
import { enCentimes, estDateIso } from '@/lib/compta/format';
import type { LigneSaisie, Retour } from '@/lib/compta/types';

const REFUS = { erreur: 'Accès refusé.' };

function rafraichir() {
  revalidatePath('/admin/compta', 'layout');
}

/* ------------------------------------------------------------------ */
/* Écritures                                                           */
/* ------------------------------------------------------------------ */

/** Enregistre une écriture équilibrée (contrôles refaits côté base). */
export async function saisirEcriture(p: {
  journal: string;
  date: string;
  libelle: string;
  lignes: LigneSaisie[];
  justificatif?: string | null;
}): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  if (!estDateIso(p.date)) return { erreur: 'Date invalide.' };

  const { data, error } = await supabase.rpc('compta_saisir_ecriture', {
    p_journal: p.journal,
    p_date: p.date,
    p_libelle: p.libelle,
    p_lignes: p.lignes,
    p_justificatif: p.justificatif ?? null,
  });
  if (error) return { erreur: error.message };

  const { data: e } = await supabase.from('compta_ecritures').select('piece').eq('id', data).maybeSingle();
  rafraichir();
  return { ok: `Pièce ${e?.piece ?? ''} enregistrée.`, id: data as string };
}

/** Annule une pièce par une écriture inverse. */
export async function contrepasser(id: string, motif?: string): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { data, error } = await supabase.rpc('compta_contrepasser', {
    p_ecriture_id: id,
    p_date: null,
    p_motif: motif?.trim() || null,
  });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Pièce annulée par une écriture inverse.', id: data as string };
}

export async function joindreJustificatif(id: string, chemin: string): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { error } = await supabase.rpc('compta_joindre_justificatif', { p_ecriture_id: id, p_chemin: chemin });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Justificatif joint.' };
}

/* ------------------------------------------------------------------ */
/* Ventes du site                                                      */
/* ------------------------------------------------------------------ */

export async function importerVentes(): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { data, error } = await supabase.rpc('compta_importer_ventes');
  if (error) return { erreur: error.message };
  rafraichir();
  const n = (data as number) ?? 0;
  return { ok: n === 0 ? 'Aucune nouvelle vente à importer.' : `${n} vente(s) importée(s).` };
}

export async function marquerVerifie(id: string): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { error } = await supabase.rpc('compta_marquer_verifie', { p_ecriture_id: id });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Vente classée.' };
}

/** Réglages d'une source de ventes (admin). */
export async function reglerSource(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const cle = String(fd.get('cle') ?? '');
  const taux = parseFloat(String(fd.get('taux_frais') ?? '0').replace(',', '.'));
  const fixe = enCentimes(String(fd.get('frais_fixe') ?? '0') || '0');
  if (!Number.isFinite(taux) || taux < 0 || taux >= 100) return { erreur: 'Taux de frais invalide.' };
  if (fixe === null) return { erreur: 'Frais fixe invalide.' };

  const { error } = await supabase
    .from('compta_sources')
    .update({ actif: fd.get('actif') === 'on', taux_frais: taux, frais_fixe_centimes: fixe })
    .eq('cle', cle);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Réglages enregistrés.' };
}

/* ------------------------------------------------------------------ */
/* Rapprochement bancaire                                              */
/* ------------------------------------------------------------------ */

export async function pointerLignes(ids: string[], pointe: boolean): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const { error } = await supabase.rpc('compta_pointer', { p_ligne_ids: ids, p_pointe: pointe });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Pointage enregistré.' };
}

export async function validerRapprochement(compte: string, date: string, soldeCentimes: number): Promise<Retour> {
  const { supabase, isStaff, user } = await requireAdmin();
  if (!isStaff || !user) return REFUS;
  if (!estDateIso(date)) return { erreur: 'Date de relevé invalide.' };
  const { data: moi } = await supabase.from('admins').select('nom').eq('id', user.id).maybeSingle();
  const { error } = await supabase.from('compta_rapprochements').upsert(
    {
      compte_numero: compte,
      date_releve: date,
      solde_releve_centimes: soldeCentimes,
      valide_par_nom: moi?.nom ?? user.email ?? null,
    },
    { onConflict: 'compte_numero,date_releve' }
  );
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Rapprochement validé.' };
}

/* ------------------------------------------------------------------ */
/* Événements et budgets                                               */
/* ------------------------------------------------------------------ */

export async function enregistrerEvenement(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const id = String(fd.get('id') ?? '');
  const code = String(fd.get('code') ?? '').trim().toUpperCase();
  const libelle = String(fd.get('libelle') ?? '').trim();
  const date = String(fd.get('date_evenement') ?? '');
  const statut = String(fd.get('statut') ?? 'en_cours');
  if (!/^[A-Z0-9-]{2,12}$/.test(code)) return { erreur: 'Code : 2 à 12 lettres, chiffres ou tirets.' };
  if (!libelle) return { erreur: 'Le libellé est obligatoire.' };

  const ligne = { code, libelle, date_evenement: estDateIso(date) ? date : null, statut };
  const { error } = id
    ? await supabase.from('compta_evenements').update(ligne).eq('id', id)
    : await supabase.from('compta_evenements').insert(ligne);
  if (error) return { erreur: error.message.includes('duplicate') ? 'Ce code existe déjà.' : error.message };
  rafraichir();
  return { ok: id ? 'Événement modifié.' : 'Événement créé.' };
}

/**
 * Crée un événement à la volée depuis l'écran de saisie (événement passé ou absent du site).
 * Le code est déduit du libellé ; il reste modifiable dans « Budgets par événement ».
 */
export async function creerEvenementRapide(libelleSaisi: string, date: string): Promise<{
  erreur?: string;
  evenement?: { id: string; code: string; libelle: string; date_evenement: string | null; statut: 'a_venir' | 'en_cours' | 'termine' };
}> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const libelle = libelleSaisi.trim();
  if (libelle.length < 2) return { erreur: 'Le nom de l\u2019événement est obligatoire.' };
  if (date && !estDateIso(date)) return { erreur: 'Date invalide.' };

  // Code : lettres et chiffres du libellé, sans accents, 10 caractères au plus.
  const base =
    libelle.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) || 'EVT';
  const { data: pris } = await supabase.from('compta_evenements').select('code').like('code', `${base.slice(0, 8)}%`);
  const codes = new Set((pris ?? []).map((e) => e.code));
  let code = base;
  for (let n = 2; codes.has(code); n++) code = `${base.slice(0, 8)}-${n}`;

  const jour = new Date().toISOString().slice(0, 10);
  const statut = !date ? 'en_cours' : date < jour ? 'termine' : 'a_venir';
  const { data, error } = await supabase
    .from('compta_evenements')
    .insert({ code, libelle, date_evenement: date || null, statut })
    .select('id, code, libelle, date_evenement, statut')
    .single();
  if (error || !data) return { erreur: error?.message ?? 'Création impossible.' };
  rafraichir();
  return { evenement: data };
}

/** Fixe le montant prévu d'un compte pour un événement (0 retire la ligne). */
export async function enregistrerBudget(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isStaff } = await requireAdmin();
  if (!isStaff) return REFUS;
  const evt = String(fd.get('compta_evenement_id') ?? '');
  const compte = String(fd.get('compte_numero') ?? '');
  const centimes = enCentimes(String(fd.get('montant') ?? ''));
  if (!evt || !compte) return { erreur: 'Événement et compte obligatoires.' };
  if (centimes === null) return { erreur: 'Montant invalide.' };

  const { error } =
    centimes === 0
      ? await supabase.from('compta_budgets').delete().eq('compta_evenement_id', evt).eq('compte_numero', compte)
      : await supabase
          .from('compta_budgets')
          .upsert(
            { compta_evenement_id: evt, compte_numero: compte, montant_centimes: centimes },
            { onConflict: 'compta_evenement_id,compte_numero' }
          );
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Budget enregistré.' };
}

/* ------------------------------------------------------------------ */
/* Plan comptable et exercices (admin)                                 */
/* ------------------------------------------------------------------ */

export async function enregistrerCompte(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const numero = String(fd.get('numero') ?? '').trim();
  const intitule = String(fd.get('intitule') ?? '').trim();
  const type = String(fd.get('type') ?? '');
  if (!/^[1-7][0-9]{5}$/.test(numero)) return { erreur: 'Numéro de compte : 6 chiffres, classe 1 à 7.' };
  if (!intitule) return { erreur: 'L\u2019intitulé est obligatoire.' };
  if (!['bilan', 'tresorerie', 'charge', 'produit'].includes(type)) return { erreur: 'Type de compte invalide.' };

  const { error } = await supabase.from('compta_comptes').upsert({ numero, intitule, type }, { onConflict: 'numero' });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: `Compte ${numero} enregistré.` };
}

export async function basculerCompte(numero: string, actif: boolean): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const { error } = await supabase.from('compta_comptes').update({ actif }).eq('numero', numero);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Compte mis à jour.' };
}

export async function creerExercice(_prev: Retour, fd: FormData): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const libelle = String(fd.get('libelle') ?? '').trim();
  const debut = String(fd.get('date_debut') ?? '');
  const fin = String(fd.get('date_fin') ?? '');
  if (!libelle || !estDateIso(debut) || !estDateIso(fin) || fin <= debut) {
    return { erreur: 'Libellé et dates obligatoires, la fin après le début.' };
  }
  const { data: chevauche } = await supabase
    .from('compta_exercices').select('libelle').lte('date_debut', fin).gte('date_fin', debut).limit(1);
  if (chevauche && chevauche.length > 0) return { erreur: `Ces dates chevauchent l\u2019exercice ${chevauche[0].libelle}.` };

  const { error } = await supabase.from('compta_exercices').insert({ libelle, date_debut: debut, date_fin: fin });
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: `Exercice ${libelle} créé.` };
}

/** Clôture ou réouverture d'un exercice. Un exercice clôturé refuse toute nouvelle écriture. */
export async function basculerExercice(id: string, cloture: boolean): Promise<Retour> {
  const { supabase, isAdmin } = await requireAdmin();
  if (!isAdmin) return REFUS;
  const { error } = await supabase
    .from('compta_exercices')
    .update({ cloture, cloture_le: cloture ? new Date().toISOString() : null })
    .eq('id', id);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: cloture ? 'Exercice clôturé.' : 'Exercice rouvert.' };
}
