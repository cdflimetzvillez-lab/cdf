'use server';

import { randomBytes } from 'crypto';
import { revalidatePath } from 'next/cache';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { MODULES_ATTRIBUABLES } from '@/lib/bureau/modules';

export type EtatBureau = { ok?: string; erreur?: string; motDePasse?: string } | null;

const REFUS = { erreur: 'Réservé aux administrateurs.' };
/** Valeur de la liste des postes qui désigne un administrateur (accès complet). */
const ADMIN = 'admin';

function rafraichir() {
  revalidatePath('/admin', 'layout');
}

/** Mot de passe provisoire lisible, à transmettre au membre. */
function motDePasseProvisoire() {
  return randomBytes(9).toString('base64url');
}

function fiche(poste: string) {
  return poste === ADMIN ? { role: 'admin', poste: null } : { role: 'membre', poste };
}

/* ------------------------------------------------------------------ */
/* Membres                                                             */
/* ------------------------------------------------------------------ */

/** Crée le compte d'un membre (ou rattache un compte existant) et lui attribue un poste. */
export async function creerMembre(_prev: EtatBureau, fd: FormData): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const nom = String(fd.get('nom') ?? '').trim();
  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const poste = String(fd.get('poste') ?? '');
  if (nom.length < 2) return { erreur: 'Le nom est obligatoire.' };
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { erreur: 'Adresse e-mail invalide.' };
  if (!poste) return { erreur: 'Choisis un poste.' };

  const db = createAdminClient();
  const { data: deja } = await db.from('admins').select('id').ilike('email', email).maybeSingle();
  if (deja) return { erreur: 'Cette adresse a déjà un accès.' };

  const motDePasse = motDePasseProvisoire();
  let id: string | null = null;

  const { data: cree, error } = await db.auth.admin.createUser({ email, password: motDePasse, email_confirm: true });
  if (cree?.user) {
    id = cree.user.id;
  } else {
    // Le compte de connexion existe peut-être déjà : on le retrouve et on lui donne un nouveau mot de passe.
    for (let page = 1; page <= 20 && !id; page++) {
      const { data: liste } = await db.auth.admin.listUsers({ page, perPage: 200 });
      const trouve = liste?.users.find((u) => u.email?.toLowerCase() === email);
      if (trouve) id = trouve.id;
      if (!liste || liste.users.length < 200) break;
    }
    if (!id) return { erreur: error?.message ?? 'Création du compte impossible.' };
    await db.auth.admin.updateUserById(id, { password: motDePasse });
  }

  const { error: errFiche } = await db.from('admins').insert({ id, email, nom, actif: true, ...fiche(poste) });
  if (errFiche) {
    return {
      erreur: /poste|actif|bureau_postes|role/.test(errFiche.message)
        ? 'La base n\u2019est pas à jour : exécute supabase/bureau.sql dans Supabase, puis réessaie.'
        : errFiche.message,
    };
  }

  rafraichir();
  return { ok: `Accès créé pour ${nom} (${email}).`, motDePasse };
}

/** Change le poste d'un membre, ou le passe administrateur. */
export async function changerPoste(id: string, poste: string): Promise<EtatBureau> {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) return REFUS;
  if (id === user.id && poste !== ADMIN) return { erreur: 'Tu ne peux pas retirer ton propre accès administrateur.' };

  const { error } = await createAdminClient().from('admins').update(fiche(poste)).eq('id', id);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Poste mis à jour.' };
}

export async function basculerMembre(id: string, actif: boolean): Promise<EtatBureau> {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) return REFUS;
  if (id === user.id) return { erreur: 'Tu ne peux pas désactiver ton propre compte.' };

  const { error } = await createAdminClient().from('admins').update({ actif }).eq('id', id);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: actif ? 'Accès réactivé.' : 'Accès désactivé.' };
}

/** Génère un nouveau mot de passe provisoire pour un membre. */
export async function nouveauMotDePasse(id: string): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const motDePasse = motDePasseProvisoire();
  const { error } = await createAdminClient().auth.admin.updateUserById(id, { password: motDePasse });
  if (error) return { erreur: error.message };
  return { ok: 'Nouveau mot de passe généré.', motDePasse };
}

/** Retire définitivement l'accès d'un membre, ainsi que son compte de connexion. */
export async function supprimerMembre(id: string): Promise<EtatBureau> {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) return REFUS;
  if (id === user.id) return { erreur: 'Tu ne peux pas supprimer ton propre compte.' };

  const db = createAdminClient();
  const { error } = await db.from('admins').delete().eq('id', id);
  if (error) return { erreur: error.message };
  await db.auth.admin.deleteUser(id); // sans effet si le compte de connexion a déjà disparu
  rafraichir();
  return { ok: 'Accès supprimé.' };
}

/* ------------------------------------------------------------------ */
/* Postes et modules                                                   */
/* ------------------------------------------------------------------ */

/** Accorde ou retire un module à un poste. */
export async function basculerAcces(poste: string, module: string, accorde: boolean): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;
  if (!MODULES_ATTRIBUABLES.some((m) => m.cle === module)) return { erreur: 'Module inconnu.' };

  const db = createAdminClient();
  const { data } = await db.from('bureau_postes').select('modules').eq('cle', poste).maybeSingle();
  if (!data) return { erreur: 'Poste introuvable.' };
  const actuels = (data.modules as string[]) ?? [];
  const modules = accorde ? [...new Set([...actuels, module])] : actuels.filter((m) => m !== module);

  const { error } = await db.from('bureau_postes').update({ modules }).eq('cle', poste);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Accès mis à jour.' };
}

export async function ajouterPoste(_prev: EtatBureau, fd: FormData): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const libelle = String(fd.get('libelle') ?? '').trim();
  if (libelle.length < 2) return { erreur: 'Le nom du poste est obligatoire.' };
  const cle = libelle.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
  if (cle.length < 2 || cle === ADMIN) return { erreur: 'Nom de poste invalide.' };

  const db = createAdminClient();
  const { count } = await db.from('bureau_postes').select('cle', { count: 'exact', head: true });
  const { error } = await db.from('bureau_postes').insert({ cle, libelle, modules: ['tableau'], position: (count ?? 0) + 1 });
  if (error) return { erreur: error.message.includes('duplicate') ? 'Ce poste existe déjà.' : error.message };
  rafraichir();
  return { ok: `Poste « ${libelle} » ajouté.` };
}

export async function supprimerPoste(cle: string): Promise<EtatBureau> {
  const { superAdmin } = await requireAdmin('bureau');
  if (!superAdmin) return REFUS;

  const db = createAdminClient();
  const { count } = await db.from('admins').select('id', { count: 'exact', head: true }).eq('poste', cle);
  if ((count ?? 0) > 0) return { erreur: 'Ce poste est encore attribué à un membre : change d\u2019abord son poste.' };
  const { error } = await db.from('bureau_postes').delete().eq('cle', cle);
  if (error) return { erreur: error.message };
  rafraichir();
  return { ok: 'Poste supprimé.' };
}
