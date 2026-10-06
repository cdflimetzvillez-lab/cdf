'use client';
import { useState } from 'react';

/** Indices révélés un par un, puis solution de secours en dernier recours.
 *  Le bloc ne s'affiche pas quand la mission n'a ni indice ni solution de secours. */
export default function Indices({ indices: liste, secours }: { indices: string[] | null; secours?: string }) {
  const [reveles, setReveles] = useState(0);
  const [secoursVu, setSecoursVu] = useState(false);
  const indices = (liste ?? []).filter((i) => i.trim());
  const tousVus = reveles >= indices.length;
  if (indices.length === 0 && !secours?.trim()) return null;

  return (
    <div className="tdn-indices">
      <h3>Besoin d&apos;un coup de pouce ?</h3>
      {indices.slice(0, reveles).map((ind, i) => (
        <div key={i} className="tdn-indice">
          <div className="tdn-sur">Indice {i + 1}</div>
          <p>{ind}</p>
        </div>
      ))}
      {!tousVus && (
        <button type="button" className="tdn-btn tdn-btn-ghost" onClick={() => setReveles((r) => r + 1)}>
          Révéler l&apos;indice {reveles + 1}
        </button>
      )}
      {tousVus && secours && !secoursVu && (
        <button type="button" className="tdn-lien" onClick={() => setSecoursVu(true)}>
          Toujours bloqué ? Voir la solution de secours
        </button>
      )}
      {secoursVu && secours && (
        <div className="tdn-indice tdn-indice-secours">
          <div className="tdn-sur">Solution de secours</div>
          <p>{secours}</p>
        </div>
      )}
    </div>
  );
}
