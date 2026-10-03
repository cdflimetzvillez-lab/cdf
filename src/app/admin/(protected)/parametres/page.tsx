import { requireAdmin } from '@/lib/supabase/server';
import FormReglages from '@/components/FormReglages';
import type { SiteSettings } from '@/lib/types';

export default async function Parametres() {
  const { supabase } = await requireAdmin('parametres');
  const { data } = await supabase.from('site_settings').select('*').eq('id', 1).single();

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Réglages du site</h1>
          <p>Textes de la page d&apos;accueil, couleurs, logo et coordonnées.</p>
        </div>
      </div>
      <FormReglages settings={data as SiteSettings} />
    </>
  );
}
