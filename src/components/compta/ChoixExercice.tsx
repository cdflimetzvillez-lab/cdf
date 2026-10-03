'use client';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import type { Exercice } from '@/lib/compta/types';

/** Liste déroulante de l'exercice affiché. Conserve les autres filtres de la page. */
export default function ChoixExercice({ exercices, courant }: { exercices: Exercice[]; courant: string }) {
  const router = useRouter();
  const path = usePathname();
  const params = useSearchParams();
  if (exercices.length < 2) return null;

  return (
    <select
      aria-label="Exercice"
      value={courant}
      onChange={(e) => {
        const p = new URLSearchParams(params.toString());
        p.set('ex', e.target.value);
        // Les dates d'un autre exercice n'ont plus de sens.
        p.delete('du');
        p.delete('au');
        router.push(`${path}?${p.toString()}`);
      }}
      style={{ font: 'inherit', fontSize: 13, padding: '5px 7px', border: '1px solid #C9D0D8', borderRadius: 3, background: '#fff' }}
    >
      {exercices.map((e) => (
        <option key={e.id} value={e.id}>
          Exercice {e.libelle}{e.cloture ? ' (clôturé)' : ''}
        </option>
      ))}
    </select>
  );
}
