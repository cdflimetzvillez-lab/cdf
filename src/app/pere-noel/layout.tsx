import type { Metadata } from 'next';
import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { requireAdmin } from '@/lib/supabase/server';
import Ciel from '@/components/pere-noel/Ciel';
import './pere-noel.css';

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  const r = await lireReglagesPn();
  return { title: `${r.titre} · Comité des Fêtes`, description: r.accroche };
}

export default async function PereNoelLayout({ children }: { children: React.ReactNode }) {
  const r = await lireReglagesPn();
  if (!r.module_actif) {
    const { isAdmin } = await requireAdmin();
    if (!isAdmin) {
      return (
        <div className="pn">
          <Ciel />
          <main className="pn-page pn-centre" style={{ paddingTop: '20vh' }}>
            <h1 className="pn-titre">{r.titre}</h1>
            <p className="pn-l clair">Ce service n&apos;est pas disponible pour le moment. Revenez bientôt !</p>
            <Link href="/" className="pn-btn ghost">Retour au site</Link>
          </main>
        </div>
      );
    }
  }
  return (
    <div className="pn">
      <Ciel />
      <div className="pn-head">
        <Link href="/pere-noel" className="logo">✦ {r.titre}</Link>
        <Link href="/" className="cdf">Une action du Comité des Fêtes</Link>
      </div>
      {children}
      <div className="pn-foot">Une action du Comité des Fêtes. Les bénéfices financent les événements de l&apos;année. Aucune donnée d&apos;enfant n&apos;est publiée.</div>
    </div>
  );
}
