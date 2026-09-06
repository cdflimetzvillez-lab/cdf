import type { Bloc } from '@/lib/tresors/types';

/** Rend un bloc de contenu de mission (texte, image, audio ou vidéo fictifs). */
export default function BlocMission({ bloc }: { bloc: Bloc }) {
  switch (bloc.type) {
    case 'texte':
      return <p className="tdn-recit">{bloc.contenu}</p>;
    case 'image':
      return (
        <figure className="tdn-media">
          <div className="tdn-media-img" role="img" aria-label={bloc.alt}>
            <svg viewBox="0 0 320 180" aria-hidden="true">
              <rect width="320" height="180" fill="#0f2150" />
              <circle cx="160" cy="80" r="46" fill="none" stroke="#e5c07b" strokeWidth="4" />
              <line x1="160" y1="80" x2="160" y2="50" stroke="#e5c07b" strokeWidth="4" strokeLinecap="round" />
              <line x1="160" y1="80" x2="182" y2="92" stroke="#e5c07b" strokeWidth="4" strokeLinecap="round" />
              <text x="160" y="152" textAnchor="middle" fill="#e5c07b" fontSize="14" fontFamily="DM Mono, monospace" letterSpacing="3">PHOTO DU LIEU</text>
            </svg>
          </div>
          {bloc.legende && <figcaption>{bloc.legende}</figcaption>}
        </figure>
      );
    case 'audio':
      return (
        <div className="tdn-media tdn-media-ligne">
          <span className="tdn-play" aria-hidden="true">▶</span>
          <div><b>{bloc.titre}</b><small>Audio · {bloc.duree}</small></div>
          <div className="tdn-onde" aria-hidden="true">{Array.from({ length: 18 }).map((_, i) => <i key={i} style={{ height: `${30 + ((i * 37) % 60)}%` }} />)}</div>
        </div>
      );
    case 'video':
      return (
        <div className="tdn-media">
          <div className="tdn-media-img tdn-media-video">
            <span className="tdn-play tdn-play-grand" aria-hidden="true">▶</span>
          </div>
          <figcaption><b>{bloc.titre}</b> · Vidéo · {bloc.duree}</figcaption>
        </div>
      );
  }
}
