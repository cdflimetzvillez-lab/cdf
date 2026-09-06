'use client';
import { useTransition } from 'react';
import { choisirParticipant } from '@/app/tresors-actions';
import type { Progression } from '@/lib/tresors/types';

export default function SelecteurParticipant({ progressions, actifId, marqueCle = false }: { progressions: Progression[]; actifId: string | null; marqueCle?: boolean }) {
  const [pending, start] = useTransition();
  if (progressions.length < 2) return null;
  return (
    <div className="tdn-chips" role="radiogroup" aria-label="Changer de participant" style={{ opacity: pending ? .6 : 1 }}>
      {progressions.map(({ participant: p, cle }) => (
        <button key={p.id} type="button" role="radio" aria-checked={p.id === actifId} className={p.id === actifId ? 'on' : ''}
          onClick={() => start(() => choisirParticipant(p.id))}>
          {p.prenom}{marqueCle && cle ? ' 🗝' : ''}{!p.paye ? ' ⏳' : ''}
        </button>
      ))}
    </div>
  );
}
