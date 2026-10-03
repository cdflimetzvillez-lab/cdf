'use client';
import { useRef, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { contrepasser, joindreJustificatif } from '@/app/compta-actions';
import { ACCEPT_JUSTIFICATIF, envoyerJustificatif } from '@/components/compta/envoi';
import type { Retour } from '@/lib/compta/types';

type Props = {
  id: string;
  piece: string;
  annee: string;
  annulable: boolean;
  aJustificatif: boolean;
};

/** Actions sur une pièce : annulation par écriture inverse, ajout du justificatif. */
export default function ActionsPiece({ id, piece, annee, annulable, aJustificatif }: Props) {
  const router = useRouter();
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  const input = useRef<HTMLInputElement>(null);

  function annuler() {
    const motif = window.prompt(`Annuler la pièce ${piece} par une écriture inverse ?\nMotif (facultatif) :`, '');
    if (motif === null) return;
    start(async () => {
      const r = await contrepasser(id, motif);
      setRetour(r);
      if (r?.ok) router.refresh();
    });
  }

  function joindre(fichier: File | undefined) {
    if (!fichier) return;
    start(async () => {
      try {
        const chemin = await envoyerJustificatif(fichier, annee);
        const r = await joindreJustificatif(id, chemin);
        setRetour(r);
        if (r?.ok) router.refresh();
      } catch (e: any) {
        setRetour({ erreur: e?.message ?? "L'envoi a échoué." });
      } finally {
        if (input.current) input.current.value = '';
      }
    });
  }

  return (
    <>
      {retour?.ok && <div className="cpt-msg ok">{retour.ok}</div>}
      {retour?.erreur && <div className="cpt-msg ko">{retour.erreur}</div>}
      <div className="cpt-outils">
        <button type="button" className="cpt-btn" disabled={pending} onClick={() => input.current?.click()}>
          {aJustificatif ? 'Remplacer le justificatif' : 'Joindre un justificatif'}
        </button>
        <input ref={input} type="file" accept={ACCEPT_JUSTIFICATIF} hidden onChange={(e) => joindre(e.target.files?.[0])} />
        {annulable && (
          <button type="button" className="cpt-btn" disabled={pending} onClick={annuler}>
            Annuler cette pièce
          </button>
        )}
      </div>
    </>
  );
}
