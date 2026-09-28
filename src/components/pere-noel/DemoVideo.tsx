'use client';
import { useRef, useState } from 'react';

export default function DemoVideo({ src, poster }: { src: string; poster?: string | null }) {
  const ref = useRef<HTMLVideoElement>(null);
  const [joue, setJoue] = useState(false);
  const lancer = () => { const v = ref.current; if (!v) return; if (v.paused) { v.play(); setJoue(true); } else { v.pause(); setJoue(false); } };
  return (
    <div className={`pn-demo${joue ? ' joue' : ''}`} onClick={lancer} role="button" aria-label="Lire la vidéo de démonstration">
      <video ref={ref} src={src} poster={poster ?? undefined} playsInline preload="metadata" controls={joue} onEnded={() => setJoue(false)} onPause={() => setJoue(false)} onPlay={() => setJoue(true)} />
      <div className="voile">
        <div className="play" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="30" height="30" fill="currentColor"><path d="M8 5.5v13a1 1 0 0 0 1.53.85l10.2-6.5a1 1 0 0 0 0-1.7L9.53 4.65A1 1 0 0 0 8 5.5z" /></svg>
        </div>
        <div className="legende">Écoute le Père Noël répondre à Léa</div>
        <div className="sous">Un exemple de vidéo, telle que la recevra ton enfant</div>
      </div>
    </div>
  );
}
