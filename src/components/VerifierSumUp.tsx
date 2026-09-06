'use client';
import { useState, useTransition } from 'react';
import { verifierSumUpAdmin } from '@/app/reservation-actions';

/** Bouton global : réinterroge SumUp pour toutes les réservations en attente. */
export default function VerifierSumUp({ nb }: { nb: number }) {
  const [pending, start] = useTransition();
  const [msg, setMsg] = useState('');
  if (nb === 0) return null;
  return (
    <span style={{ display: 'inline-flex', flexDirection: 'column', alignItems: 'flex-end', gap: '.3rem' }}>
      <button className="btn btn-y btn-sm" disabled={pending}
        onClick={() => start(async () => { const r = await verifierSumUpAdmin(); setMsg(r.erreur ?? `${r.verifiees} vérifiée${r.verifiees > 1 ? 's' : ''}, ${r.changees} mise${r.changees > 1 ? 's' : ''} à jour`); })}>
        {pending ? 'Vérification…' : `Vérifier les ${nb} en attente sur SumUp`}
      </button>
      {msg && <small style={{ color: '#6b6560' }}>{msg}</small>}
    </span>
  );
}
