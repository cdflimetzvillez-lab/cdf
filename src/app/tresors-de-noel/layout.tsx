import type { Metadata } from 'next';
import { lireReglages } from '@/lib/tresors/db';
import './tresors.css';

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  const r = await lireReglages();
  return { title: `${r.titre} · Comité des Fêtes`, description: `${r.accroche} Une chasse aux trésors grandeur nature dans le village.` };
}

export default function TresorsLayout({ children }: { children: React.ReactNode }) {
  return <div className="tdn">{children}</div>;
}
