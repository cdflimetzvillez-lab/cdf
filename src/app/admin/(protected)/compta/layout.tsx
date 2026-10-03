import { Suspense } from 'react';
import { requireAdmin } from '@/lib/supabase/server';
import NavCompta from '@/components/compta/NavCompta';
import './compta.css';

export const dynamic = 'force-dynamic';

export default async function LayoutCompta({ children }: { children: React.ReactNode }) {
  const { supabase } = await requireAdmin();

  // Tant que le script SQL n'a pas été exécuté, on l'indique au lieu de planter.
  const { error } = await supabase.from('compta_exercices').select('id').limit(1);
  if (error) {
    return (
      <div className="cpt">
        <div className="cpt-panneau">
          <h2>Module comptabilité non installé</h2>
          <p className="cpt-info">
            Exécute le fichier <code>supabase/comptabilite.sql</code> dans l&apos;éditeur SQL du projet Supabase du CDF,
            puis recharge cette page.
          </p>
          <p className="cpt-ko">{error.message}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="cpt">
      <Suspense fallback={<div className="cpt-nav" />}>
        <NavCompta />
      </Suspense>
      {children}
    </div>
  );
}
