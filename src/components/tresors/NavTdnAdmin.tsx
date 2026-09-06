'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const ONGLETS = [
  { href: '/admin/tresors', label: 'Tableau de bord' },
  { href: '/admin/tresors/missions', label: 'Missions' },
  { href: '/admin/tresors/lots', label: 'Lots & partenaires' },
  { href: '/admin/tresors/participants', label: 'Participants' },
  { href: '/admin/tresors/cles', label: 'Clés' },
  { href: '/admin/tresors/reglages', label: 'Réglages' },
];

export default function NavTdnAdmin() {
  const path = usePathname();
  return (
    <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap', marginBottom: '1.6rem' }}>
      {ONGLETS.map((o) => {
        const actif = o.href === '/admin/tresors' ? path === o.href : path.startsWith(o.href);
        return <Link key={o.href} href={o.href} className={`btn btn-sm ${actif ? 'btn-k' : 'btn-w'}`}>{o.label}</Link>;
      })}
    </div>
  );
}
