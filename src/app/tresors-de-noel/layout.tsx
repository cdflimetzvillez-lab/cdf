import type { Metadata } from 'next';
import { TresorsProvider } from '@/lib/tresors/store';
import { EVENEMENT } from '@/lib/tresors/mock';
import './tresors.css';

export const metadata: Metadata = {
  title: `${EVENEMENT.titre} · Comité des Fêtes`,
  description: `${EVENEMENT.accroche} Une chasse aux trésors grandeur nature dans le village.`,
};

export default function TresorsLayout({ children }: { children: React.ReactNode }) {
  return (
    <TresorsProvider>
      <div className="tdn">{children}</div>
    </TresorsProvider>
  );
}
