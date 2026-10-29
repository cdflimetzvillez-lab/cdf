'use client';
import { useActionState } from 'react';
import { inscrireListeAttente, type ActionState } from '@/app/actions';

export default function FormulaireListeAttente(
  { evenementId, placesMax }: { evenementId: string; placesMax: number }
) {
  const [state, action, pending] = useActionState<ActionState, FormData>(inscrireListeAttente, null);

  if (state?.ok) {
    return (
      <div className="form-box">
        <h3>Vous êtes sur la liste</h3>
        <div className="msg ok">{state.ok}</div>
        <p style={{ fontSize: '.9rem', color: '#6b6560' }}>
          Un email de confirmation vient de vous être envoyé.
        </p>
      </div>
    );
  }

  const max = Math.max(1, Math.min(50, placesMax || 10));

  return (
    <form className="form-box" action={action}>
      <h3>Complet : liste d&apos;attente</h3>
      <p style={{ fontWeight: 600, marginBottom: '1.1rem', lineHeight: 1.5 }}>
        Toutes les places ont trouvé preneur. Laissez vos coordonnées : en cas de
        désistement, nous vous contactons dans l&apos;ordre des inscriptions.
      </p>
      {state?.error && <div className="msg ko">{state.error}</div>}

      <input type="hidden" name="evenement_id" value={evenementId} />

      <div className="field">
        <label htmlFor="la-nom">Nom et prénom</label>
        <input id="la-nom" name="nom" required placeholder="Ex. Marie Dupont" />
      </div>
      <div className="field">
        <label htmlFor="la-email">Email</label>
        <input id="la-email" name="email" type="email" required placeholder="vous@exemple.fr" />
      </div>
      <div className="field">
        <label htmlFor="la-telephone">Téléphone (facultatif)</label>
        <input id="la-telephone" name="telephone" type="tel" placeholder="06 12 34 56 78" />
      </div>
      <div className="field">
        <label htmlFor="la-places">Nombre de places souhaitées</label>
        <select id="la-places" name="places" defaultValue="2">
          {Array.from({ length: max }, (_, i) => i + 1).map((n) => (
            <option key={n} value={n}>{n} place{n > 1 ? 's' : ''}</option>
          ))}
        </select>
      </div>
      <div className="field">
        <label htmlFor="la-message">Message (facultatif)</label>
        <textarea id="la-message" name="message" rows={2} placeholder="Une précision pour le comité ?" />
      </div>

      <button className="btn btn-k" style={{ width: '100%' }} disabled={pending}>
        {pending ? 'Envoi…' : 'M\u2019inscrire sur la liste d\u2019attente'}
      </button>
      <p style={{ fontSize: '.78rem', color: '#6b6560', marginTop: '.8rem' }}>
        Aucun paiement n&apos;est demandé. Vos coordonnées servent uniquement à vous recontacter pour cet événement.
      </p>
    </form>
  );
}
