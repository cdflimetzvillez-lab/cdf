import type { ThemeAccueil } from '@/lib/theme/types';
import './theme.css';

/** Motif du thème : ruban de sensibilisation ou étoile. Les flocons sont un fond, voir Neige. */
export function Motif({ theme }: { theme: ThemeAccueil }) {
  if (theme.motif === 'ruban') {
    const trace = 'M13 86 L40 32 C47 17 40 8 30 8 C20 8 13 17 20 32 L47 86';
    return (
      <svg className="th-motif" viewBox="0 0 60 92" aria-hidden="true" focusable="false">
        <path d={trace} fill="none" stroke="#141014" strokeWidth="17" strokeLinejoin="round" />
        <path d={trace} fill="none" stroke={theme.couleur} strokeWidth="10" strokeLinejoin="round" />
      </svg>
    );
  }
  if (theme.motif === 'etoile' || theme.motif === 'flocons') {
    return <span className="th-etoile" aria-hidden="true">✷</span>;
  }
  return null;
}

/** Fond de flocons du haut de page. */
export function Neige({ theme }: { theme: ThemeAccueil }) {
  return theme.motif === 'flocons' ? <div className="th-neige" aria-hidden="true" /> : null;
}

/** Pastille inclinée portant le nom du thème. */
export function PastilleTheme({ theme }: { theme: ThemeAccueil }) {
  return (
    <div className="th-pastille">
      <Motif theme={theme} />
      <b>{theme.nom}</b>
    </div>
  );
}

/** Bloc de message sous le bandeau défilant. Rien n'est affiché sans titre ni texte. */
export function BlocTheme({ theme, style }: { theme: ThemeAccueil; style?: React.CSSProperties }) {
  if (!theme.titre && !theme.texte) return null;
  const externe = /^https?:\/\//.test(theme.lien);
  return (
    <section className="th-bloc" style={style} aria-label={theme.nom}>
      <div className="th-bloc-in">
        <Motif theme={theme} />
        <div>
          {theme.titre && <h2>{theme.titre}</h2>}
          {theme.texte && <p>{theme.texte}</p>}
          {theme.lien && (
            <a className="btn btn-k" href={theme.lien} {...(externe ? { target: '_blank', rel: 'noreferrer' } : {})}>
              {theme.bouton || 'En savoir plus'}
            </a>
          )}
        </div>
      </div>
    </section>
  );
}
