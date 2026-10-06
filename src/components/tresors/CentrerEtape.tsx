'use client';
import { useEffect } from 'react';

/**
 * La carte du parcours est plus haute que l'écran d'un téléphone : à l'ouverture de la page,
 * on fait défiler jusqu'au repère posé sur l'étape en cours (ou sur le coffre, à la fin).
 */
export default function CentrerEtape({ cle }: { cle: string }) {
  useEffect(() => {
    document.getElementById('tdn-map-repere')?.scrollIntoView({ block: 'center' });
  }, [cle]);
  return null;
}
