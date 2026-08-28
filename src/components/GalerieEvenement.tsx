'use client';
import { useEffect, useState } from 'react';

type Doc = {
  id: string;
  url: string;
  titre: string | null;
  legende: string | null;
  type: string;
};

export default function GalerieEvenement({ documents }: { documents: Doc[] }) {
  const [ouvert, setOuvert] = useState<number | null>(null);
  const images = documents.filter((d) => d.type === 'image');

  useEffect(() => {
    if (ouvert === null) return;
    document.body.style.overflow = 'hidden';
    const clavier = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOuvert(null);
      if (e.key === 'ArrowRight') setOuvert((o) => (o === null ? null : (o + 1) % images.length));
      if (e.key === 'ArrowLeft') setOuvert((o) => (o === null ? null : (o - 1 + images.length) % images.length));
    };
    window.addEventListener('keydown', clavier);
    return () => {
      window.removeEventListener('keydown', clavier);
      document.body.style.overflow = '';
    };
  }, [ouvert, images.length]);

  if (documents.length === 0) return null;

  return (
    <>
      <div className="galerie">
        {documents.map((doc) => {
          if (doc.type === 'pdf') {
            return (
              <a key={doc.id} href={doc.url} target="_blank" rel="noreferrer"
                className="gal-carte gal-pdf">
                <span className="gal-badge">PDF</span>
                <div className="gal-legende">
                  <strong>{doc.titre || 'Document'}</strong>
                  {doc.legende && <span>{doc.legende}</span>}
                </div>
              </a>
            );
          }
          const index = images.findIndex((i) => i.id === doc.id);
          return (
            <button key={doc.id} className="gal-carte" onClick={() => setOuvert(index)}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={doc.url} alt={doc.titre ?? ''} loading="lazy" />
              {(doc.titre || doc.legende) && (
                <div className="gal-legende">
                  {doc.titre && <strong>{doc.titre}</strong>}
                  {doc.legende && <span>{doc.legende}</span>}
                </div>
              )}
            </button>
          );
        })}
      </div>

      {ouvert !== null && images[ouvert] && (
        <div className="gal-visio" onClick={() => setOuvert(null)}>
          <button className="gal-fermer" aria-label="Fermer">✕</button>

          {images.length > 1 && (
            <>
              <button className="gal-nav gal-prec" aria-label="Précédent"
                onClick={(e) => { e.stopPropagation();
                  setOuvert((o) => (o! - 1 + images.length) % images.length); }}>‹</button>
              <button className="gal-nav gal-suiv" aria-label="Suivant"
                onClick={(e) => { e.stopPropagation();
                  setOuvert((o) => (o! + 1) % images.length); }}>›</button>
            </>
          )}

          <figure onClick={(e) => e.stopPropagation()}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={images[ouvert].url} alt={images[ouvert].titre ?? ''} />
            {(images[ouvert].titre || images[ouvert].legende) && (
              <figcaption>
                {images[ouvert].titre && <strong>{images[ouvert].titre}</strong>}
                {images[ouvert].legende && <span>{images[ouvert].legende}</span>}
              </figcaption>
            )}
          </figure>
        </div>
      )}
    </>
  );
}
