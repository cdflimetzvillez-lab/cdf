'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LIENS = [
  { href: '/tresors-de-noel', label: 'Accueil', icone: '✦' },
  { href: '/tresors-de-noel/aventure', label: 'Aventure', icone: '🧭' },
  { href: '/tresors-de-noel/cle', label: 'Ma clé', icone: '🗝' },
  { href: '/tresors-de-noel/compte', label: 'Compte', icone: '👤' },
];

/** Barre de navigation basse, pensée pour le pouce. */
export default function NavTresors() {
  const path = usePathname();
  return (
    <nav className="tdn-nav" aria-label="Navigation du jeu">
      {LIENS.map((l) => {
        const actif = l.href === '/tresors-de-noel' ? path === l.href : path.startsWith(l.href);
        return (
          <Link key={l.href} href={l.href} className={actif ? 'on' : ''} aria-current={actif ? 'page' : undefined}>
            <span aria-hidden="true">{l.icone}</span>
            {l.label}
          </Link>
        );
      })}
    </nav>
  );
}
