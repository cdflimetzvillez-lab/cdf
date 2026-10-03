'use client';

export default function Imprimer({ libelle = 'Imprimer' }: { libelle?: string }) {
  return (
    <button type="button" className="cpt-btn" onClick={() => window.print()}>
      {libelle}
    </button>
  );
}
