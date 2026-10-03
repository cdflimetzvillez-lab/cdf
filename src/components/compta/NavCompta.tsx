'use client';
import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';

const BASE = '/admin/compta';
const ONGLETS = [
  { href: BASE, label: 'Tableau de bord' },
  { href: `${BASE}/saisie`, label: 'Saisie' },
  { href: `${BASE}/ventes`, label: 'Ventes du site' },
  { href: `${BASE}/journaux`, label: 'Journaux' },
  { href: `${BASE}/grand-livre`, label: 'Grand livre' },
  { href: `${BASE}/balance`, label: 'Balance' },
  { href: `${BASE}/resultat`, label: 'Compte de résultat' },
  { href: `${BASE}/budgets`, label: 'Budgets par événement' },
  { href: `${BASE}/rapprochement`, label: 'Rapprochement bancaire' },
  { href: `${BASE}/plan`, label: 'Plan et exercices' },
];

export default function NavCompta() {
  const path = usePathname();
  const ex = useSearchParams().get('ex');
  const suffixe = ex ? `?ex=${ex}` : '';

  const actif = (href: string) => {
    if (href === BASE) return path === BASE;
    if (href === `${BASE}/journaux` && path.startsWith(`${BASE}/piece`)) return true;
    return path.startsWith(href);
  };

  return (
    <nav className="cpt-nav" aria-label="Menu de la comptabilité">
      {ONGLETS.map((o) => (
        <Link key={o.href} href={`${o.href}${suffixe}`} className={actif(o.href) ? 'on' : ''}>
          {o.label}
        </Link>
      ))}
    </nav>
  );
}
