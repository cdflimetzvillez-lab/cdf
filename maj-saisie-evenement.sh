#!/usr/bin/env bash
# Comptabilité : création d'un événement directement depuis l'écran de saisie.
# À exécuter à la racine du projet :  bash maj-saisie-evenement.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d "src/app/admin/(protected)/compta" ]; then
  echo "Lance ce script à la racine du repo, après l'installation du module comptabilité."; exit 1
fi
echo "Mise à jour : nouvel événement depuis la saisie…"
mkdir -p 'src/app'
cat > 'src/app/compta-actions.ts' <<'EOF_SAISIE_FICHIER'
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
EOF_SAISIE_FICHIER
echo "  ✓ src/app/compta-actions.ts"
mkdir -p 'src/components/compta'
cat > 'src/components/compta/FormSaisie.tsx' <<'EOF_SAISIE_FICHIER'
'use client';
import { useMemo, useRef, useState, useTransition } from 'react';
import Link from 'next/link';
import { creerEvenementRapide, saisirEcriture } from '@/app/compta-actions';
import { enCentimes, montant, montantOuVide } from '@/lib/compta/format';
import { ACCEPT_JUSTIFICATIF, envoyerJustificatif } from '@/components/compta/envoi';
import type { Compte, EvenementCompta, Journal, LigneSaisie, Retour } from '@/lib/compta/types';

type Props = {
  comptes: Compte[];
  journaux: Journal[];
  evenements: EvenementCompta[];
  dateDefaut: string;
};

type Mode = 'guidee' | 'libre';
type TypeOp = 'depense' | 'recette' | 'virement';
type LigneLibre = { cle: number; compte: string; evenement: string; debit: string; credit: string };

const ligneVide = (cle: number): LigneLibre => ({ cle, compte: '', evenement: '', debit: '', credit: '' });

/** Valeur de la liste « Événement » qui ouvre la création d'un événement. */
const NOUVEAU = '__nouveau';

export default function FormSaisie({ comptes, journaux, evenements: evenementsInitiaux, dateDefaut }: Props) {
  // Événements créés depuis cet écran, visibles tout de suite dans les listes.
  const [ajoutes, setAjoutes] = useState<EvenementCompta[]>([]);
  const evenements = useMemo(
    () => [...evenementsInitiaux, ...ajoutes.filter((a) => !evenementsInitiaux.some((e) => e.id === a.id))]
      .sort((a, b) => a.code.localeCompare(b.code)),
    [evenementsInitiaux, ajoutes]
  );
  const [creation, setCreation] = useState(false);
  const [nomEvt, setNomEvt] = useState('');
  const [dateEvt, setDateEvt] = useState('');
  const [erreurEvt, setErreurEvt] = useState('');

  const actifs = useMemo(() => comptes.filter((c) => c.actif), [comptes]);
  const tresos = actifs.filter((c) => c.type === 'tresorerie');
  const charges = actifs.filter((c) => c.type === 'charge');
  const produits = actifs.filter((c) => c.type === 'produit');
  const intitule = (n: string) => comptes.find((c) => c.numero === n)?.intitule ?? '';
  const codeEvt = (id?: string | null) => evenements.find((e) => e.id === id)?.code ?? '';
  const banque = tresos.find((c) => c.numero === '512000')?.numero ?? tresos[0]?.numero ?? '';

  const [mode, setMode] = useState<Mode>('guidee');
  const [type, setType] = useState<TypeOp>('depense');
  const [date, setDate] = useState(dateDefaut);
  const [libelle, setLibelle] = useState('');
  const [montantTxt, setMontantTxt] = useState('');
  const [compte, setCompte] = useState('');
  const [treso, setTreso] = useState(banque);
  const [tresoVers, setTresoVers] = useState(tresos.find((c) => c.numero !== banque)?.numero ?? '');
  const [evenement, setEvenement] = useState('');
  const [journalLibre, setJournalLibre] = useState('OD');
  const [lignesLibres, setLignesLibres] = useState<LigneLibre[]>([ligneVide(1), ligneVide(2)]);
  const [fichier, setFichier] = useState<File | null>(null);
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  const compteur = useRef(3);
  const inputFichier = useRef<HTMLInputElement>(null);

  const liste = type === 'depense' ? charges : produits;
  const compteEff = liste.some((c) => c.numero === compte) ? compte : liste[0]?.numero ?? '';
  const journalDe = (numero: string) => journaux.find((j) => j.compte_tresorerie === numero)?.code;

  // Lignes de l'écriture et journal, selon le mode de saisie.
  const { lignes, journal, invalide } = useMemo(() => {
    if (mode === 'libre') {
      let invalide = false;
      const lignes: LigneSaisie[] = [];
      for (const l of lignesLibres) {
        if (!l.compte && !l.debit && !l.credit) continue;
        const d = l.debit.trim() ? enCentimes(l.debit) : 0;
        const c = l.credit.trim() ? enCentimes(l.credit) : 0;
        if (!l.compte || d === null || c === null || (d > 0) === (c > 0)) invalide = true;
        lignes.push({ compte: l.compte, debit: d ?? 0, credit: c ?? 0, evenement_id: l.evenement || null });
      }
      return { lignes, journal: journalLibre, invalide };
    }

    const m = enCentimes(montantTxt) ?? 0;
    const evt = evenement || null;
    if (type === 'depense') {
      return {
        lignes: [
          { compte: compteEff, debit: m, credit: 0, evenement_id: evt },
          { compte: treso, debit: 0, credit: m },
        ] as LigneSaisie[],
        journal: journalDe(treso) ?? 'OD',
        invalide: false,
      };
    }
    if (type === 'recette') {
      return {
        lignes: [
          { compte: treso, debit: m, credit: 0 },
          { compte: compteEff, debit: 0, credit: m, evenement_id: evt },
        ] as LigneSaisie[],
        journal: journalDe(treso) ?? 'OD',
        invalide: false,
      };
    }
    const codes = [journalDe(treso), journalDe(tresoVers)];
    return {
      lignes: [
        { compte: tresoVers, debit: m, credit: 0 },
        { compte: treso, debit: 0, credit: m },
      ] as LigneSaisie[],
      journal: codes.includes('BQ') ? 'BQ' : codes.find(Boolean) ?? 'OD',
      invalide: treso === tresoVers,
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, type, montantTxt, compteEff, treso, tresoVers, evenement, journalLibre, lignesLibres, journaux]);

  const totalDebit = lignes.reduce((s, l) => s + l.debit, 0);
  const totalCredit = lignes.reduce((s, l) => s + l.credit, 0);
  const equilibree = !invalide && lignes.length >= 2 && totalDebit === totalCredit && totalDebit > 0;

  function majLigne(cle: number, champ: keyof Omit<LigneLibre, 'cle'>, valeur: string) {
    setLignesLibres((ls) => ls.map((l) => (l.cle === cle ? { ...l, [champ]: valeur } : l)));
  }

  function creerEvenement() {
    setErreurEvt('');
    start(async () => {
      const r = await creerEvenementRapide(nomEvt, dateEvt);
      if (r.erreur || !r.evenement) {
        setErreurEvt(r.erreur ?? 'Création impossible.');
        return;
      }
      setAjoutes((l) => [...l, r.evenement!]);
      setEvenement(r.evenement.id); // sélectionné d'office en saisie guidée
      setCreation(false);
      setNomEvt('');
      setDateEvt('');
    });
  }

  function valider() {
    setRetour(null);
    if (!date) return setRetour({ erreur: 'La date est obligatoire.' });
    if (!libelle.trim()) return setRetour({ erreur: 'Le libellé est obligatoire.' });
    if (!equilibree) {
      return setRetour({
        erreur: mode === 'libre'
          ? 'Écriture déséquilibrée ou ligne incomplète : chaque ligne porte un compte et un seul montant.'
          : type === 'virement' && treso === tresoVers
            ? 'Choisis deux comptes de trésorerie différents.'
            : 'Montant invalide.',
      });
    }

    start(async () => {
      let chemin: string | null = null;
      if (fichier) {
        try {
          chemin = await envoyerJustificatif(fichier, date.slice(0, 4));
        } catch (e: any) {
          setRetour({ erreur: e?.message ?? "L'envoi du justificatif a échoué." });
          return;
        }
      }
      const r = await saisirEcriture({ journal, date, libelle, lignes, justificatif: chemin });
      setRetour(r);
      if (r?.ok) {
        setLibelle('');
        setMontantTxt('');
        setFichier(null);
        if (inputFichier.current) inputFichier.current.value = '';
        setLignesLibres([ligneVide(compteur.current++), ligneVide(compteur.current++)]);
      }
    });
  }

  const optionsCompte = (liste: Compte[]) =>
    liste.map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>);

  return (
    <>
      {retour?.ok && (
        <div className="cpt-msg ok">
          {retour.ok}{' '}
          {retour.id && <Link href={`/admin/compta/piece/${retour.id}`}>Voir la pièce</Link>}
        </div>
      )}
      {retour?.erreur && <div className="cpt-msg ko">{retour.erreur}</div>}

      <div className="cpt-panneau">
        <div className="cpt-outils" style={{ marginBottom: 10 }}>
          <button type="button" className={`cpt-btn${mode === 'guidee' ? ' p' : ''}`} onClick={() => setMode('guidee')}>
            Saisie guidée
          </button>
          <button type="button" className={`cpt-btn${mode === 'libre' ? ' p' : ''}`} onClick={() => setMode('libre')}>
            Saisie libre
          </button>
        </div>

        <div className="cpt-champs">
          {mode === 'guidee' ? (
            <div className="cpt-champ">
              <label htmlFor="s-type">Type</label>
              <select id="s-type" value={type} onChange={(e) => setType(e.target.value as TypeOp)}>
                <option value="depense">Dépense</option>
                <option value="recette">Recette</option>
                <option value="virement">Virement interne</option>
              </select>
            </div>
          ) : (
            <div className="cpt-champ">
              <label htmlFor="s-journal">Journal</label>
              <select id="s-journal" value={journalLibre} onChange={(e) => setJournalLibre(e.target.value)}>
                {journaux.map((j) => <option key={j.code} value={j.code}>{j.code}, {j.libelle}</option>)}
              </select>
            </div>
          )}
          <div className="cpt-champ">
            <label htmlFor="s-date">Date</label>
            <input id="s-date" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          </div>
          <div className="cpt-champ l2">
            <label htmlFor="s-libelle">Libellé</label>
            <input id="s-libelle" type="text" value={libelle} maxLength={160} onChange={(e) => setLibelle(e.target.value)} />
          </div>

          {mode === 'guidee' && (
            <>
              <div className="cpt-champ">
                <label htmlFor="s-montant">Montant</label>
                <input id="s-montant" className="n" type="text" inputMode="decimal" placeholder="0,00"
                  value={montantTxt} onChange={(e) => setMontantTxt(e.target.value)} />
              </div>
              {type === 'virement' ? (
                <>
                  <div className="cpt-champ">
                    <label htmlFor="s-de">Depuis</label>
                    <select id="s-de" value={treso} onChange={(e) => setTreso(e.target.value)}>{optionsCompte(tresos)}</select>
                  </div>
                  <div className="cpt-champ l2">
                    <label htmlFor="s-vers">Vers</label>
                    <select id="s-vers" value={tresoVers} onChange={(e) => setTresoVers(e.target.value)}>{optionsCompte(tresos)}</select>
                  </div>
                </>
              ) : (
                <>
                  <div className="cpt-champ">
                    <label htmlFor="s-treso">{type === 'depense' ? 'Payé par' : 'Encaissé sur'}</label>
                    <select id="s-treso" value={treso} onChange={(e) => setTreso(e.target.value)}>{optionsCompte(tresos)}</select>
                  </div>
                  <div className="cpt-champ l2">
                    <label htmlFor="s-compte">{type === 'depense' ? 'Compte de charge' : 'Compte de produit'}</label>
                    <select id="s-compte" value={compteEff} onChange={(e) => setCompte(e.target.value)}>{optionsCompte(liste)}</select>
                  </div>
                  <div className="cpt-champ l2">
                    <label htmlFor="s-evt">Événement</label>
                    <select id="s-evt" value={creation ? NOUVEAU : evenement}
                      onChange={(e) => {
                        if (e.target.value === NOUVEAU) { setCreation(true); return; }
                        setCreation(false);
                        setEvenement(e.target.value);
                      }}>
                      <option value="">Aucun, fonctionnement général</option>
                      {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}, {e.libelle}</option>)}
                      <option value={NOUVEAU}>+ Nouvel événement (absent de la liste)</option>
                    </select>
                  </div>
                </>
              )}
            </>
          )}

          <div className="cpt-champ l2">
            <label htmlFor="s-fichier">Justificatif (PDF ou photo)</label>
            <input id="s-fichier" ref={inputFichier} type="file" accept={ACCEPT_JUSTIFICATIF}
              onChange={(e) => setFichier(e.target.files?.[0] ?? null)} />
          </div>
        </div>

        {creation && (
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px solid #C9D0D8' }}>
            <h2>Nouvel événement</h2>
            {erreurEvt && <div className="cpt-msg ko">{erreurEvt}</div>}
            <div className="cpt-ligne">
              <div className="cpt-champ" style={{ flex: '2 1 220px' }}>
                <label htmlFor="s-nevt">Nom de l&apos;événement</label>
                <input id="s-nevt" type="text" value={nomEvt} maxLength={80} placeholder="Ex. Brocante de mai 2026"
                  onChange={(e) => setNomEvt(e.target.value)} />
              </div>
              <div className="cpt-champ">
                <label htmlFor="s-devt">Date (facultatif)</label>
                <input id="s-devt" type="date" value={dateEvt} onChange={(e) => setDateEvt(e.target.value)} />
              </div>
              <button type="button" className="cpt-btn p" disabled={pending} onClick={creerEvenement}>
                Créer l&apos;événement
              </button>
              <button type="button" className="cpt-btn" onClick={() => { setCreation(false); setErreurEvt(''); }}>
                Annuler
              </button>
            </div>
            <p className="cpt-info" style={{ marginTop: 8, marginBottom: 0 }}>
              Pour un événement passé ou qui n&apos;est pas sur le site. Il apparaît ensuite dans la liste et dans les budgets.
            </p>
          </div>
        )}
      </div>

      <div className="cpt-panneau">
        <h2>Lignes de l&apos;écriture, journal {journal}</h2>
        <div className="cpt-defile">
          <table className="cpt-grille">
            <thead>
              <tr>
                <th>Compte</th>
                {mode === 'guidee' && <th>Intitulé</th>}
                <th>Évt</th>
                <th className="n">Débit</th>
                <th className="n">Crédit</th>
                {mode === 'libre' && <th></th>}
              </tr>
            </thead>
            <tbody>
              {mode === 'guidee'
                ? lignes.map((l, i) => (
                    <tr key={i}>
                      <td className="fixe">{l.compte}</td>
                      <td>{intitule(l.compte)}</td>
                      <td>{codeEvt(l.evenement_id)}</td>
                      <td className="n">{montantOuVide(l.debit)}</td>
                      <td className="n">{montantOuVide(l.credit)}</td>
                    </tr>
                  ))
                : lignesLibres.map((l) => (
                    <tr key={l.cle}>
                      <td>
                        <select aria-label="Compte" value={l.compte} onChange={(e) => majLigne(l.cle, 'compte', e.target.value)}>
                          <option value="">Choisir un compte</option>
                          {optionsCompte(actifs)}
                        </select>
                      </td>
                      <td>
                        <select aria-label="Événement" value={l.evenement} onChange={(e) => majLigne(l.cle, 'evenement', e.target.value)}>
                          <option value="">Aucun</option>
                          {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}
                        </select>
                      </td>
                      <td>
                        <input aria-label="Débit" className="n" type="text" inputMode="decimal" value={l.debit}
                          onChange={(e) => majLigne(l.cle, 'debit', e.target.value)} />
                      </td>
                      <td>
                        <input aria-label="Crédit" className="n" type="text" inputMode="decimal" value={l.credit}
                          onChange={(e) => majLigne(l.cle, 'credit', e.target.value)} />
                      </td>
                      <td>
                        <button type="button" className="cpt-btn mini" aria-label="Retirer la ligne"
                          disabled={lignesLibres.length <= 2}
                          onClick={() => setLignesLibres((ls) => ls.filter((x) => x.cle !== l.cle))}>
                          Retirer
                        </button>
                      </td>
                    </tr>
                  ))}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={mode === 'guidee' ? 3 : 2}>Totaux</td>
                <td className="n">{montant(totalDebit)}</td>
                <td className="n">{montant(totalCredit)}</td>
                {mode === 'libre' && <td></td>}
              </tr>
            </tfoot>
          </table>
        </div>

        {equilibree
          ? <p className="cpt-ok">Écriture équilibrée.</p>
          : <p className="cpt-ko">Écriture incomplète ou déséquilibrée.</p>}

        <div className="cpt-outils" style={{ marginTop: 10 }}>
          <button type="button" className="cpt-btn p" disabled={pending} onClick={valider}>
            {pending ? 'Enregistrement…' : "Valider l'écriture"}
          </button>
          {mode === 'libre' && (
            <>
              <button type="button" className="cpt-btn"
                onClick={() => setLignesLibres((ls) => [...ls, ligneVide(compteur.current++)])}>
                Ajouter une ligne
              </button>
              <button type="button" className="cpt-btn" onClick={() => setCreation(true)}>
                Nouvel événement
              </button>
            </>
          )}
        </div>
      </div>
    </>
  );
}
EOF_SAISIE_FICHIER
echo "  ✓ src/components/compta/FormSaisie.tsx"

echo
echo "Terminé : 2 fichiers écrits. Aucune mise à jour de la base n'est nécessaire."
echo "Ensuite : git add -A && git commit -m 'Compta : nouvel événement depuis la saisie' && git push && vercel --prod"
