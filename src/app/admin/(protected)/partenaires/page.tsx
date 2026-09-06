import { requireAdmin } from '@/lib/supabase/server';
import GestionPartenaires from '@/components/GestionPartenaires';
import type { Partenaire } from '@/lib/types';

export default async function AdminPartenaires() {
  const { supabase } = await requireAdmin();
  const { data } = await supabase.from('partenaires').select('*').order('position');
  return (
    <>
      <div className="adm-h">
        <div><h1>Partenaires</h1><p>Logos affichés sous le programme sur la page d&apos;accueil. La barre défile automatiquement à partir de 5 logos.</p></div>
      </div>
      <GestionPartenaires partenaires={(data ?? []) as Partenaire[]} />
    </>
  );
}
