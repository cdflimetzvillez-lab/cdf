'use client';
import { useActionState } from 'react';
import { enregistrerBudget, enregistrerEvenement } from '@/app/compta-actions';
import type { Compte, EvenementCompta, Retour } from '@/lib/compta/types';

function Message({ etat }: { etat: Retour }) {
  if (etat?.ok) return <div className="cpt-msg ok">{etat.ok}</div>;
  if (etat?.erreur) return <div className="cpt-msg ko">{etat.erreur}</div>;
  return null;
}

/** Création ou modification d'un code événement. */
export function FormEvenement({ evenement }: { evenement?: EvenementCompta | null }) {
  const [etat, action, pending] = useActionState<Retour, FormData>(enregistrerEvenement, null);
  const p = evenement ? 'em' : 'en'; // deux formulaires peuvent cohabiter sur la page
  return (
    <form action={action} key={evenement?.id ?? 'nouveau'}>
      <Message etat={etat} />
      <input type="hidden" name="id" value={evenement?.id ?? ''} />
      <div className="cpt-ligne">
        <div className="cpt-champ" style={{ flex: '0 1 120px' }}>
          <label htmlFor={`${p}-code`}>Code</label>
          <input id={`${p}-code`} name="code" defaultValue={evenement?.code ?? ''} maxLength={12} required />
        </div>
        <div className="cpt-champ" style={{ flex: '2 1 200px' }}>
          <label htmlFor={`${p}-libelle`}>Libellé</label>
          <input id={`${p}-libelle`} name="libelle" defaultValue={evenement?.libelle ?? ''} required />
        </div>
        <div className="cpt-champ">
          <label htmlFor={`${p}-date`}>Date</label>
          <input id={`${p}-date`} name="date_evenement" type="date" defaultValue={evenement?.date_evenement ?? ''} />
        </div>
        <div className="cpt-champ">
          <label htmlFor={`${p}-statut`}>Statut</label>
          <select id={`${p}-statut`} name="statut" defaultValue={evenement?.statut ?? 'en_cours'}>
            <option value="a_venir">À venir</option>
            <option value="en_cours">En cours</option>
            <option value="termine">Terminé</option>
          </select>
        </div>
        <button className="cpt-btn p" disabled={pending}>{evenement ? 'Enregistrer' : "Créer l'événement"}</button>
      </div>
    </form>
  );
}

/** Montant prévu d'un compte pour un événement. Un montant à 0 retire la ligne. */
export function FormBudget({ evenementId, comptes }: { evenementId: string; comptes: Compte[] }) {
  const [etat, action, pending] = useActionState<Retour, FormData>(enregistrerBudget, null);
  const postes = comptes.filter((c) => c.actif && (c.type === 'charge' || c.type === 'produit'));
  return (
    <form action={action}>
      <Message etat={etat} />
      <input type="hidden" name="compta_evenement_id" value={evenementId} />
      <div className="cpt-ligne">
        <div className="cpt-champ" style={{ flex: '2 1 240px' }}>
          <label htmlFor="b-compte">Poste</label>
          <select id="b-compte" name="compte_numero" required>
            <optgroup label="Recettes">
              {postes.filter((c) => c.type === 'produit').map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
            </optgroup>
            <optgroup label="Dépenses">
              {postes.filter((c) => c.type === 'charge').map((c) => <option key={c.numero} value={c.numero}>{c.numero}, {c.intitule}</option>)}
            </optgroup>
          </select>
        </div>
        <div className="cpt-champ">
          <label htmlFor="b-montant">Montant prévu</label>
          <input id="b-montant" name="montant" className="n" type="text" inputMode="decimal" placeholder="0,00" required />
        </div>
        <button className="cpt-btn p" disabled={pending}>Enregistrer le prévu</button>
      </div>
    </form>
  );
}
