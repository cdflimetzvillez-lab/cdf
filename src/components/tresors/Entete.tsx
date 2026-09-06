import Link from 'next/link';

/** En-tête compact des pages internes : retour + titre. */
export default function Entete({ titre, retour = '/tresors-de-noel', sur }: { titre: string; retour?: string; sur?: string }) {
  return (
    <header className="tdn-entete">
      <Link href={retour} className="tdn-retour" aria-label="Retour">←</Link>
      <div>
        {sur && <div className="tdn-sur">{sur}</div>}
        <h1>{titre}</h1>
      </div>
    </header>
  );
}
