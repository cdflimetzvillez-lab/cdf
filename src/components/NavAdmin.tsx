'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LIENS = [
  { href: '/admin', label: 'Tableau de bord' },
  { href: '/admin/evenements', label: 'Événements' },
  { href: '/admin/reservations', label: 'Réservations' },
  { href: '/admin/demandes', label: 'Demandes reçues' },
  { href: '/admin/tresors', label: 'Trésors de Noël' },
  { href: '/admin/roue', label: '🎡 Roue de la Rentrée' },
  { href: '/admin/partenaires', label: 'Partenaires' },
  { href: '/admin/association', label: 'Association' },
  { href: '/admin/parametres', label: 'Réglages du site' },
  { href: '/admin/maintenance', label: 'Maintenance' },
];

export default function NavAdmin() {
  const path = usePathname();
  const [ouvert, setOuvert] = useState(false);
  useEffect(() => { setOuvert(false); }, [path]);
  const estActif = (href: string) => (href === '/admin' ? path === '/admin' : path.startsWith(href));
  const courant = LIENS.find((l) => estActif(l.href))?.label ?? 'Menu';

  return (
    <nav className={`adm-nav${ouvert ? ' ouvert' : ''}`}>
      <button type="button" className="adm-nav-btn" aria-expanded={ouvert} onClick={() => setOuvert((v) => !v)}>
        <span>{courant}</span>
        <span aria-hidden="true">{ouvert ? '✕' : '☰'}</span>
      </button>
      <div className="adm-nav-liens">
        {LIENS.map((l) => (
          <Link key={l.href} href={l.href} className={estActif(l.href) ? 'on' : ''}>
            {l.label}
          </Link>
        ))}
      </div>
    </nav>
  );
}
