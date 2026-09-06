'use client';
import { useActionState } from 'react';
import { envoyerLienAcces, type Etat } from '@/app/tresors-actions';

export default function FormAcces() {
  const [etat, action, pending] = useActionState<Etat, FormData>(envoyerLienAcces, null);
  return (
    <form action={action}>
      {etat?.ok && <p className="tdn-indice" style={{ marginBottom: '1rem' }}>{etat.ok}</p>}
      {etat?.erreur && <p className="tdn-erreur">{etat.erreur}</p>}
      <div className="tdn-champ"><label htmlFor="email">E-mail</label>
        <input id="email" name="email" type="email" inputMode="email" autoComplete="email" required /></div>
      <button className="tdn-btn tdn-btn-or tdn-btn-large" disabled={pending}>{pending ? 'Envoi…' : 'Recevoir mon lien d’accès'}</button>
    </form>
  );
}
