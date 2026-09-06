/** Hotte du Père Noël débordant de cadeaux, avec son halo intégré (rien ne déborde du SVG). */
export default function Hotte({ className = '', etiquette = '' }: { className?: string; etiquette?: string }) {
  return (
    <svg className={className} viewBox="0 0 400 320" aria-hidden="true">
      <defs>
        <radialGradient id="hotte-halo" cx="50%" cy="55%" r="50%">
          <stop offset="0%" stopColor="rgba(229,192,123,.55)" /><stop offset="45%" stopColor="rgba(229,192,123,.12)" /><stop offset="100%" stopColor="rgba(229,192,123,0)" />
        </radialGradient>
        <linearGradient id="hotte-sac" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#a63a4b" /><stop offset="1" stopColor="#6b1f2c" /></linearGradient>
        <linearGradient id="hotte-or" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#f3d99a" /><stop offset="1" stopColor="#c99a3b" /></linearGradient>
        <linearGradient id="hotte-vert" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#2f7a5c" /><stop offset="1" stopColor="#1f5c45" /></linearGradient>
        <linearGradient id="hotte-bleu" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#3b5aa3" /><stop offset="1" stopColor="#172c63" /></linearGradient>
      </defs>
      <ellipse cx="200" cy="175" rx="200" ry="150" fill="url(#hotte-halo)" />

      {/* cadeaux qui dépassent */}
      <g transform="rotate(-12 150 118)"><rect x="118" y="88" width="62" height="60" rx="5" fill="url(#hotte-vert)" /><rect x="118" y="112" width="62" height="12" fill="url(#hotte-or)" /><rect x="143" y="88" width="12" height="60" fill="url(#hotte-or)" /></g>
      <g transform="rotate(10 250 108)"><rect x="216" y="70" width="70" height="72" rx="5" fill="url(#hotte-bleu)" /><rect x="216" y="100" width="70" height="12" fill="#fbf7ef" /><rect x="245" y="70" width="12" height="72" fill="#fbf7ef" /><path d="M251 66 c-12 -14 -28 -2 -10 6 c-18 0 -8 -18 10 -6 c18 -12 28 6 10 6 c18 -8 2 -20 -10 -6z" fill="#fbf7ef" /></g>
      <rect x="180" y="96" width="48" height="52" rx="5" fill="url(#hotte-or)" /><rect x="180" y="118" width="48" height="10" fill="#8a2a3a" /><rect x="199" y="96" width="10" height="52" fill="#8a2a3a" />
      {/* sucre d'orge */}
      <path d="M292 122 c0 -30 24 -32 26 -12" fill="none" stroke="#fbf7ef" strokeWidth="9" strokeLinecap="round" />
      <path d="M292 122 c0 -30 24 -32 26 -12" fill="none" stroke="#c22a45" strokeWidth="9" strokeLinecap="round" strokeDasharray="7 7" />

      {/* sac */}
      <path d="M112 150 C 90 200 86 250 104 292 Q 200 312 296 292 C 314 250 310 200 288 150 Q 200 170 112 150 Z" fill="url(#hotte-sac)" />
      <path d="M112 150 Q 200 170 288 150" fill="none" stroke="#4d1420" strokeWidth="3" />
      {/* col de la hotte */}
      <path d="M104 148 Q 200 128 296 148 L 300 160 Q 200 186 100 160 Z" fill="#fbf7ef" />
      <path d="M104 148 Q 200 128 296 148" fill="none" stroke="#d9cdb8" strokeWidth="2" />
      {/* cordon doré */}
      <path d="M120 180 Q 200 198 280 180" fill="none" stroke="url(#hotte-or)" strokeWidth="6" strokeLinecap="round" />
      <circle cx="120" cy="181" r="7" fill="url(#hotte-or)" /><circle cx="280" cy="181" r="7" fill="url(#hotte-or)" />
      {/* plis */}
      <path d="M150 200 Q 160 250 150 290 M250 200 Q 240 250 250 290" fill="none" stroke="#4d1420" strokeWidth="2" opacity=".6" />
      {/* étiquette */}
      <g transform="rotate(8 262 232)"><rect x="236" y="216" width="52" height="30" rx="3" fill="#fbf7ef" /><circle cx="243" cy="231" r="3" fill="#8a2a3a" /><text x="264" y="236" textAnchor="middle" fontFamily="Cormorant Garamond, serif" fontSize="17" fontWeight="700" fill="#8a2a3a">{etiquette}</text></g>
      {/* scintillements */}
      <g fill="#fbf7ef"><path d="M70 90 l3 8 8 3 -8 3 -3 8 -3 -8 -8 -3 8 -3z" /><path d="M330 60 l2.5 6.5 6.5 2.5 -6.5 2.5 -2.5 6.5 -2.5 -6.5 -6.5 -2.5 6.5 -2.5z" /><path d="M320 200 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2z" /></g>
    </svg>
  );
}
