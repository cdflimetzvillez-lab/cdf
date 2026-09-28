/** Ciel étoilé et neige, en pur CSS. Rendu côté serveur, aucune image. */
export default function Ciel() {
  const flocons = Array.from({ length: 26 }, (_, i) => ({
    left: (i * 37) % 100, duree: 9 + (i % 7) * 1.7, delai: -((i * 1.3) % 12), taille: 3 + (i % 4),
  }));
  return (
    <div className="pn-ciel" aria-hidden="true">
      <div className="etoiles" />
      <div className="neige">
        {flocons.map((f, i) => (
          <i key={i} style={{ left: `${f.left}%`, width: f.taille, height: f.taille, animationDuration: `${f.duree}s`, animationDelay: `${f.delai}s`, opacity: .35 + (i % 4) * .15 }} />
        ))}
      </div>
    </div>
  );
}
