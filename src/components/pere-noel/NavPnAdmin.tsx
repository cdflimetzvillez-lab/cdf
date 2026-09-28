'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const ONGLETS = [
  { href: '/admin/pere-noel', label: 'Commandes' },
  { href: '/admin/pere-noel/reglages', label: 'Réglages' },
];

export default function NavPnAdmin() {
  const path = usePathname();
  return (
    <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap', marginBottom: '1.6rem' }}>
      {ONGLETS.map((o) => {
        const actif = o.href === '/admin/pere-noel' ? !path.startsWith('/admin/pere-noel/reglages') : path.startsWith(o.href);
        return <Link key={o.href} href={o.href} className={`btn btn-sm ${actif ? 'btn-k' : 'btn-w'}`}>{o.label}</Link>;
      })}
      <Link href="/pere-noel/commander?test=1" target="_blank" className="btn btn-sm btn-y">+ Commande de test</Link>
    </div>
  );
}
