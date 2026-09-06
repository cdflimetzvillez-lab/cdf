/** Silhouette du traîneau du Père Noël tiré par trois rennes (SVG pur, couleur via currentColor). */
export default function Traineau({ className = '' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 330 80" aria-hidden="true" fill="currentColor" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round">
      <defs>
        <g id="tdn-renne">
          {/* corps */}
          <ellipse cx="34" cy="30" rx="17" ry="8.5" stroke="none" />
          {/* cou + tête */}
          <path d="M46 25 L57 11 L65 12 L52 32 Z" stroke="none" />
          <ellipse cx="63" cy="11" rx="7.5" ry="4.8" stroke="none" />
          <circle cx="70.5" cy="12.2" r="1.6" stroke="none" />
          <path d="M58 7 L56 3 L60 7 Z" stroke="none" />
          {/* bois */}
          <g fill="none" strokeWidth="1.7">
            <path d="M61 7 L57 -3 M59 2 L54 0 M58 0 L60 -5" />
            <path d="M64 7 L66 -4 M65 1 L69 -1 M65.5 -2 L63 -6" />
          </g>
          {/* pattes en course */}
          <g fill="none" strokeWidth="3">
            <path d="M45 36 L52 47 L58 44" />
            <path d="M41 37 L38 48 L42 52" />
            <path d="M25 36 L17 46 L11 44" />
            <path d="M29 37 L30 49 L26 53" />
          </g>
          {/* queue */}
          <path d="M18 27 L12 22 L16 29 Z" stroke="none" />
        </g>
      </defs>

      {/* traîneau */}
      <g transform="translate(0 14)">
        {/* patin */}
        <path d="M6 58 Q-2 50 10 48 L 96 48 Q 110 48 112 36 Q 113 30 108 31" fill="none" strokeWidth="3.2" />
        <path d="M22 48 L20 40 M86 48 L88 40" fill="none" strokeWidth="2.6" />
        {/* caisse */}
        <path d="M12 42 L18 22 Q20 15 28 15 L76 15 Q86 15 90 25 L95 42 Z" stroke="none" />
        <path d="M90 25 Q100 10 92 4 Q86 1 87 8" fill="none" strokeWidth="2.6" />
        {/* hotte de cadeaux */}
        <circle cx="74" cy="12" r="8" stroke="none" />
        <circle cx="66" cy="8" r="5" stroke="none" />
        {/* Père Noël */}
        <ellipse cx="44" cy="16" rx="11" ry="8.5" stroke="none" />
        <circle cx="46" cy="3" r="5.5" stroke="none" />
        <path d="M41 1 L49 -8 L54 3 Z" stroke="none" />
        <circle cx="49.5" cy="-8" r="1.8" stroke="none" />
        {/* bras et rênes */}
        <path d="M52 12 L64 8" fill="none" strokeWidth="3" />
        <path d="M64 8 L125 12 M125 12 L185 8 M185 8 L245 5" fill="none" strokeWidth="1.2" />
      </g>

      {/* rennes */}
      <use href="#tdn-renne" x="118" y="14" />
      <use href="#tdn-renne" x="188" y="11" />
      <use href="#tdn-renne" x="258" y="8" />
    </svg>
  );
}
