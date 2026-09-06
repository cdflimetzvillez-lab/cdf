import type { Metadata } from 'next';
import Link from 'next/link';
import { lireReglages } from '@/lib/tresors/db';
import { requireAdmin } from '@/lib/supabase/server';
import './tresors.css';

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  const r = await lireReglages();
  return { title: `${r.titre} · Comité des Fêtes`, description: `${r.accroche} Une chasse aux trésors grandeur nature dans le village.` };
}

export default async function TresorsLayout({ children }: { children: React.ReactNode }) {
  const r = await lireReglages();
  if (r.module_actif === false) {
    const { isAdmin } = await requireAdmin();
    if (!isAdmin) {
      return (
        <div className="tdn">
          <main className="tdn-page tdn-centre" style={{ justifyContent: 'center' }}>
            <h1 className="tdn-titre-fee">Les Trésors de Noël</h1>
            <p className="tdn-p">Ce jeu n&apos;est pas disponible pour le moment. Revenez bientôt !</p>
            <Link href="/" className="tdn-btn tdn-btn-ghost">Retour au site</Link>
          </main>
        </div>
      );
    }
  }
  return <div className="tdn">{children}</div>;
}
