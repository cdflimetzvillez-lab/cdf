'use client';
import { useActionState, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import {
  basculerCompte, basculerExercice, creerExercice, enregistrerCompte, reglerSource,
} from '@/app/compta-actions';
import type { Retour } from '@/lib/compta/types';

function Message({ etat }: { etat: Retour }) {
  if (etat?.ok) return <div className="cpt-msg ok">{etat.ok}</div>;
  if (etat?.erreur) return <div className="cpt-msg ko">{etat.erreur}</div>;
  return null;
}

export function FormCompte() {
  const [etat, action, pending] = useActionState<Retour, FormData>(enregistrerCompte, null);
  return (
    <form action={action}>
      <Message etat={etat} />
      <div className="cpt-ligne">
        <div className="cpt-champ" style={{ flex: '0 1 120px' }}>
          <label htmlFor="c-numero">Numéro</label>
          <input id="c-numero" name="numero" inputMode="numeric" maxLength={6} placeholder="606400" required />
        </div>
        <div className="cpt-champ" style={{ flex: '2 1 220px' }}>
          <label htmlFor="c-intitule">Intitulé</label>
          <input id="c-intitule" name="intitule" required />
        </div>
        <div className="cpt-champ">
          <label htmlFor="c-type">Type</label>
          <select id="c-type" name="type" defaultValue="charge">
            <option value="charge">Charge</option>
            <option value="produit">Produit</option>
            <option value="tresorerie">Trésorerie</option>
            <option value="bilan">Bilan</option>
          </select>
        </div>
        <button className="cpt-btn p" disabled={pending}>Ajouter ou renommer</button>
      </div>
    </form>
  );
}

export function BasculeCompte({ numero, actif }: { numero: string; actif: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <button type="button" className="cpt-btn mini" disabled={pending}
      onClick={() => start(async () => { await basculerCompte(numero, !actif); router.refresh(); })}>
      {actif ? 'Désactiver' : 'Réactiver'}
    </button>
  );
}

export function FormExercice() {
  const [etat, action, pending] = useActionState<Retour, FormData>(creerExercice, null);
  return (
    <form action={action}>
      <Message etat={etat} />
      <div className="cpt-ligne">
        <div className="cpt-champ">
          <label htmlFor="x-libelle">Libellé</label>
          <input id="x-libelle" name="libelle" placeholder="2027" required />
        </div>
        <div className="cpt-champ">
          <label htmlFor="x-debut">Début</label>
          <input id="x-debut" name="date_debut" type="date" required />
        </div>
        <div className="cpt-champ">
          <label htmlFor="x-fin">Fin</label>
          <input id="x-fin" name="date_fin" type="date" required />
        </div>
        <button className="cpt-btn p" disabled={pending}>Créer l&apos;exercice</button>
      </div>
    </form>
  );
}

export function BasculeExercice({ id, libelle, cloture }: { id: string; libelle: string; cloture: boolean }) {
  const router = useRouter();
  const [erreur, setErreur] = useState('');
  const [pending, start] = useTransition();
  return (
    <>
      <button type="button" className="cpt-btn mini" disabled={pending}
        onClick={() => {
          const question = cloture
            ? `Rouvrir l'exercice ${libelle} ?`
            : `Clôturer l'exercice ${libelle} ? Plus aucune écriture ne pourra y être ajoutée.`;
          if (!window.confirm(question)) return;
          start(async () => {
            const r = await basculerExercice(id, !cloture);
            if (r?.erreur) setErreur(r.erreur);
            router.refresh();
          });
        }}>
        {cloture ? 'Rouvrir' : 'Clôturer'}
      </button>
      {erreur && <span className="cpt-etat rouge">{erreur}</span>}
    </>
  );
}

/** Réglages d'une source de ventes du site (admin). */
export function FormSource({ cle, actif, taux, fixe }: { cle: string; actif: boolean; taux: number; fixe: string }) {
  const [etat, action, pending] = useActionState<Retour, FormData>(reglerSource, null);
  return (
    <form action={action}>
      <input type="hidden" name="cle" value={cle} />
      <div className="cpt-ligne" style={{ alignItems: 'center' }}>
        <label style={{ display: 'flex', gap: 5, alignItems: 'center', whiteSpace: 'nowrap' }}>
          <input type="checkbox" name="actif" defaultChecked={actif} /> Actif
        </label>
        <label style={{ display: 'flex', gap: 5, alignItems: 'center', whiteSpace: 'nowrap' }}>
          Frais %
          <input name="taux_frais" className="n" type="text" inputMode="decimal" defaultValue={String(taux).replace('.', ',')}
            style={{ width: 64, minWidth: 0 }} />
        </label>
        <label style={{ display: 'flex', gap: 5, alignItems: 'center', whiteSpace: 'nowrap' }}>
          + fixe
          <input name="frais_fixe" className="n" type="text" inputMode="decimal" defaultValue={fixe}
            style={{ width: 64, minWidth: 0 }} />
        </label>
        <button className="cpt-btn mini" disabled={pending}>Enregistrer</button>
        {etat?.ok && <span className="cpt-etat vert">{etat.ok}</span>}
        {etat?.erreur && <span className="cpt-etat rouge">{etat.erreur}</span>}
      </div>
    </form>
  );
}
