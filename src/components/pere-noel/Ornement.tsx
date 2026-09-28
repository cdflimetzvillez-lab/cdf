/** Coin doré décoratif pour les documents imprimables. */
export function Coin({ pos }: { pos: 'hg' | 'hd' | 'bg' | 'bd' }) {
  return (
    <svg className={`pn-doc-coin ${pos}`} viewBox="0 0 44 44" fill="none" stroke="currentColor" strokeWidth="1.4" aria-hidden="true">
      <path d="M2 42V10Q2 2 10 2H42" />
      <path d="M8 42V14Q8 8 14 8H42" opacity=".55" />
      <path d="M2 2l8 8M6 2q6 3 9 9M2 6q3 6 9 9" strokeLinecap="round" />
      <circle cx="16" cy="16" r="2" fill="currentColor" stroke="none" />
    </svg>
  );
}
export function Sceau() {
  return <div className="sceau"><span>Bureau du</span><b>★</b><span>Père Noël</span><span style={{ fontSize: 8, opacity: .8 }}>Pôle Nord</span></div>;
}
