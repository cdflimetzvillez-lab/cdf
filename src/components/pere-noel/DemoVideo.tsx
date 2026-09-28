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
        <div className="play">▶</div>
        <div className="legende">Écoute le Père Noël répondre à Léa</div>
        <div className="sous">Un exemple de vidéo, telle que la recevra ton enfant</div>
      </div>
    </div>
  );
}
