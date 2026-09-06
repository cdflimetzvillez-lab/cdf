/** Silhouette de sapins et de maisons illuminées en bas de l'écran. */
export default function Village({ className = '' }: { className?: string }) {
  return (
    <svg className={`tdn-village ${className}`} viewBox="0 0 800 160" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
      <defs>
        <linearGradient id="tdn-sol" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#0d1b3d" />
          <stop offset="1" stopColor="#081430" />
        </linearGradient>
      </defs>
      <path d="M0 110 L60 100 L120 108 L180 96 L240 104 L300 94 L360 104 L420 92 L480 100 L540 90 L600 100 L660 92 L720 102 L800 96 L800 160 L0 160 Z" fill="url(#tdn-sol)" />
      {/* sapins */}
      {[40, 130, 250, 560, 700, 770].map((x, i) => (
        <g key={i} transform={`translate(${x} 0)`}>
          <polygon points="0,40 -22,84 22,84" fill="#0b1a34" />
          <polygon points="0,58 -28,104 28,104" fill="#0a1730" />
          <polygon points="0,78 -34,124 34,124" fill="#08132a" />
          <rect x="-4" y="122" width="8" height="12" fill="#06101f" />
        </g>
      ))}
      {/* maisons */}
      {[
        { x: 330, w: 70, h: 44 }, { x: 420, w: 56, h: 38 }, { x: 490, w: 62, h: 50 }, { x: 620, w: 66, h: 40 },
      ].map((m, i) => (
        <g key={i}>
          <rect x={m.x} y={122 - m.h} width={m.w} height={m.h} fill="#0c1a36" />
          <polygon points={`${m.x - 6},${122 - m.h} ${m.x + m.w / 2},${122 - m.h - 26} ${m.x + m.w + 6},${122 - m.h}`} fill="#101f42" />
          <rect x={m.x + 10} y={128 - m.h} width="12" height="12" fill="#f4c76a" className="tdn-fenetre" />
          <rect x={m.x + m.w - 22} y={128 - m.h} width="12" height="12" fill="#f4c76a" className="tdn-fenetre" style={{ animationDelay: '1.3s' }} />
        </g>
      ))}
      {/* clocher */}
      <rect x="576" y="52" width="26" height="70" fill="#0c1a36" />
      <polygon points="570,52 589,18 608,52" fill="#101f42" />
      <rect x="587" y="10" width="4" height="10" fill="#f4c76a" />
      <rect x="583" y="72" width="12" height="12" fill="#f4c76a" className="tdn-fenetre" style={{ animationDelay: '.6s' }} />
    </svg>
  );
}
