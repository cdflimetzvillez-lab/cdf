'use client';
import { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { pointerLignes, validerRapprochement } from '@/app/compta-actions';
import { dateFr, montantOuVide } from '@/lib/compta/format';
import type { Retour } from '@/lib/compta/types';

export type LignePointage = {
  id: string;
  ecriture_id: string;
  date_piece: string;
  piece: string;
  libelle: string;
  debit_centimes: number;
  credit_centimes: number;
  pointe: boolean;
};

/** Écritures d'un compte de trésorerie avec case à cocher de pointage. */
export function TablePointage({ lignes }: { lignes: LignePointage[] }) {
  const router = useRouter();
  // Coche affichée tout de suite, sans attendre la réponse du serveur.
  const [local, setLocal] = useState<Record<string, boolean>>({});
  const [erreur, setErreur] = useState('');
  const [, start] = useTransition();

  function basculer(id: string, pointe: boolean) {
    setLocal((v) => ({ ...v, [id]: pointe }));
    setErreur('');
    start(async () => {
      const r = await pointerLignes([id], pointe);
      if (r?.erreur) {
        setErreur(r.erreur);
        setLocal((v) => { const { [id]: _retire, ...reste } = v; return reste; });
      }
      router.refresh();
    });
  }

  return (
    <>
      {erreur && <div className="cpt-msg ko">{erreur}</div>}
      <div className="cpt-defile">
        <table className="cpt-grille">
          <thead>
            <tr><th>Pointé</th><th>Date</th><th>Pièce</th><th>Libellé</th><th className="n">Débit</th><th className="n">Crédit</th></tr>
          </thead>
          <tbody>
            {lignes.map((l) => (
              <tr key={l.id}>
                <td>
                  <input type="checkbox" aria-label={`Pointer ${l.piece}`} checked={local[l.id] ?? l.pointe}
                    onChange={(e) => basculer(l.id, e.target.checked)} />
                </td>
                <td className="fixe">{dateFr(l.date_piece)}</td>
                <td className="fixe"><Link href={`/admin/compta/piece/${l.ecriture_id}`}>{l.piece}</Link></td>
                <td>{l.libelle}</td>
                <td className="n">{montantOuVide(l.debit_centimes)}</td>
                <td className="n">{montantOuVide(l.credit_centimes)}</td>
              </tr>
            ))}
            {lignes.length === 0 && <tr><td colSpan={6}>Aucune écriture à pointer jusqu&apos;à cette date.</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  );
}

/** Enregistre le rapprochement quand l'écart est nul. */
export function BoutonValiderRapprochement({ compte, date, solde, possible }: {
  compte: string; date: string; solde: number | null; possible: boolean;
}) {
  const router = useRouter();
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  return (
    <div className="cpt-outils" style={{ marginTop: 10 }}>
      <button type="button" className="cpt-btn p" disabled={!possible || pending || solde === null}
        onClick={() => start(async () => {
          if (solde === null) return;
          const r = await validerRapprochement(compte, date, solde);
          setRetour(r);
          if (r?.ok) router.refresh();
        })}>
        Valider le rapprochement
      </button>
      {retour?.ok && <span className="cpt-etat vert">{retour.ok}</span>}
      {retour?.erreur && <span className="cpt-etat rouge">{retour.erreur}</span>}
    </div>
  );
}
