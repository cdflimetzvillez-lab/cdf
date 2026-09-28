'use client';
export default function BoutonImprimer() {
  return <button type="button" onClick={() => window.print()}>Imprimer ou enregistrer en PDF</button>;
}
