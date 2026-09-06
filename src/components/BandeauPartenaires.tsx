import type { Partenaire } from '@/lib/types';

/** Logos des partenaires. Défile si la ligne dépasse la largeur, sinon centrée. */
export default function BandeauPartenaires({ partenaires }: { partenaires: Partenaire[] }) {
  if (partenaires.length === 0) return null;
  const defile = partenaires.length > 4;
  const Logo = ({ p }: { p: Partenaire }) => {
    const img = <img src={p.logo_url} alt={p.nom} loading="lazy" />;
    return p.site_url
      ? <a href={p.site_url} target="_blank" rel="noopener noreferrer sponsored" className="partenaire" title={p.nom}>{img}</a>
      : <span className="partenaire" title={p.nom}>{img}</span>;
  };
  return (
    <div className="partenaires">
      <div className="wrap">
        <span className="kicker mono">Ils soutiennent le Comité des Fêtes</span>
      </div>
      <div className={`partenaires-piste${defile ? ' defile' : ''}`}>
        <div className="partenaires-ligne">
          {partenaires.map((p) => <Logo key={p.id} p={p} />)}
          {defile && partenaires.map((p) => <Logo key={`bis-${p.id}`} p={p} />)}
        </div>
      </div>
    </div>
  );
}
