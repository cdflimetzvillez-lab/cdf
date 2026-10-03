import { Suspense } from 'react';
import ChoixExercice from '@/components/compta/ChoixExercice';
import type { Exercice } from '@/lib/compta/types';

type Props = {
  titre: string;
  exercices?: Exercice[];
  exercice?: Exercice | null;
  children?: React.ReactNode;
};

/** Titre de page, choix de l'exercice et boutons d'action. */
export default function Entete({ titre, exercices, exercice, children }: Props) {
  return (
    <div className="cpt-titre">
      <h1>{titre}</h1>
      <div className="cpt-outils">
        {exercices && exercice && (
          <Suspense fallback={null}>
            <ChoixExercice exercices={exercices} courant={exercice.id} />
          </Suspense>
        )}
        {children}
      </div>
    </div>
  );
}

export function SansExercice() {
  return (
    <div className="cpt-panneau">
      <h2>Aucun exercice</h2>
      <p className="cpt-info">Crée un exercice dans « Plan et exercices » pour commencer.</p>
    </div>
  );
}
