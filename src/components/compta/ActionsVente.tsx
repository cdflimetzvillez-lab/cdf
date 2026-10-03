'use client';
import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { contrepasser, importerVentes, marquerVerifie } from '@/app/compta-actions';
import type { Retour } from '@/lib/compta/types';

/** Bouton « Relancer l'import » des ventes du site. */
export function BoutonImport() {
  const router = useRouter();
  const [retour, setRetour] = useState<Retour>(null);
  const [pending, start] = useTransition();
  return (
    <>
      {retour?.ok && <span className="cpt-etat vert">{retour.ok}</span>}
      {retour?.erreur && <span className="cpt-etat rouge">{retour.erreur}</span>}
      <button
        type="button"
        className="cpt-btn"
        disabled={pending}
        onClick={() => start(async () => { const r = await importerVentes(); setRetour(r); router.refresh(); })}
      >
        {pending ? 'Import en cours…' : "Relancer l'import"}
      </button>
    </>
  );
}

/** Actions sur une vente dont le statut a changé depuis l'import. */
export function BoutonsVente({ id, piece }: { id: string; piece: string }) {
  const router = useRouter();
  const [erreur, setErreur] = useState('');
  const [pending, start] = useTransition();

  const lancer = (action: () => Promise<Retour>) =>
    start(async () => {
      const r = await action();
      if (r?.erreur) setErreur(r.erreur);
      else router.refresh();
    });

  return (
    <div className="cpt-outils">
      <button type="button" className="cpt-btn mini p" disabled={pending}
        onClick={() => {
          if (window.confirm(`Annuler la pièce ${piece} par une écriture inverse ?`)) {
            lancer(() => contrepasser(id, 'vente remboursée ou annulée'));
          }
        }}>
        Annuler la vente
      </button>
      <button type="button" className="cpt-btn mini" disabled={pending} onClick={() => lancer(() => marquerVerifie(id))}>
        Ignorer
      </button>
      {erreur && <span className="cpt-etat rouge">{erreur}</span>}
    </div>
  );
}
