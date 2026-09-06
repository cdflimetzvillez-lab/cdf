/** Neige légère en CSS pur (pas de JS, respecte prefers-reduced-motion via le CSS). */
export default function Neige({ flocons = 40 }: { flocons?: number }) {
  return (
    <div className="tdn-neige" aria-hidden="true">
      {Array.from({ length: flocons }).map((_, i) => {
        const gauche = (i * 37) % 100;
        const duree = 9 + ((i * 7) % 8);
        const delai = -((i * 13) % 12);
        const taille = 2 + ((i * 5) % 4);
        const opacite = 0.35 + ((i * 3) % 5) / 10;
        return (
          <i key={i} style={{
            left: `${gauche}%`, width: taille, height: taille, opacity: opacite,
            animationDuration: `${duree}s`, animationDelay: `${delai}s`,
          }} />
        );
      })}
    </div>
  );
}
