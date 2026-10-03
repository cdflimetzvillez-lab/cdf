'use client';
import { useMemo, useRef, useState, useTransition } from 'react';
import Link from 'next/link';
import { saisirEcriture } from '@/app/compta-actions';
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

export default function FormSaisie({ comptes, journaux, evenements, dateDefaut }: Props) {
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
                    <select id="s-evt" value={evenement} onChange={(e) => setEvenement(e.target.value)}>
                      <option value="">Aucun, fonctionnement général</option>
                      {evenements.map((e) => <option key={e.id} value={e.id}>{e.code}, {e.libelle}</option>)}
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
            <button type="button" className="cpt-btn"
              onClick={() => setLignesLibres((ls) => [...ls, ligneVide(compteur.current++)])}>
              Ajouter une ligne
            </button>
          )}
        </div>
      </div>
    </>
  );
}
