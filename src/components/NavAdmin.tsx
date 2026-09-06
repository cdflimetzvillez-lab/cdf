'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LIENS = [
  { href: '/admin', label: 'Tableau de bord' },
  { href: '/admin/evenements', label: 'Événements' },
  { href: '/admin/reservations', label: 'Réservations' },
  { href: '/admin/demandes', label: 'Demandes reçues' },
  { href: '/admin/tresors', label: 'Trésors de Noël' },
  { href: '/admin/association', label: 'Association' },
  { href: '/admin/parametres', label: 'Réglages du site' },
  { href: '/admin/maintenance', label: 'Maintenance' },
];

export default function NavAdmin() {
  const path = usePathname();
  return (
    <nav>
      {LIENS.map((l) => {
        const actif = l.href === '/admin' ? path === '/admin' : path.startsWith(l.href);
        return (
          <Link key={l.href} href={l.href} className={actif ? 'on' : ''}>
            {l.label}
          </Link>
        );
      })}
    </nav>
  );
}
