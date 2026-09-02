import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import FormStats from '@/components/FormStats';
import type { Stat } from '@/lib/types';

export default async function Association() {
  const { supabase } = await requireAdmin();
  const { data } = await supabase.from('stats').select('*').order('position');

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Association</h1>
          <p>
            Les chiffres  clés de la page d&apos;accueil. Le texte de présentation se modifie
            dans <Link href="/admin/parametres" style={{ textDecoration: 'underline' }}>
            Réglages du site</Link>.
          </p>
        </div>
      </div>
      <FormStats stats={(data ?? []) as Stat[]} />
    </>
  );
}
