import { requireAdmin } from '@/lib/supabase/server';
import CarteRoue from '@/components/roue/CarteRoue';
import FormModuleRoue from '@/components/roue/FormModuleRoue';
import GestionLotsRoue from '@/components/roue/GestionLotsRoue';
import TableGagnants from '@/components/roue/TableGagnants';
import TestRoue from '@/components/roue/TestRoue';
import { configRoue, roueVisible } from '@/lib/roue/db';
import type { LotRoue, ModuleAccueil, ParticipationRoue, StatsRoue } from '@/lib/roue/types';

export default async function AdminRoue({ searchParams }: { searchParams: Promise<{ onglet?: string }> }) {
  const { onglet = 'apercu' } = await searchParams;
  const { supabase } = await requireAdmin();
  const [{ data: module }, { data: stats }, { data: lots }, { data: gagnants }, { data: attribs }] = await Promise.all([
    supabase.from('homepage_modules').select('*').eq('module_key', 'roue_rentree').maybeSingle(),
    supabase.from('roue_stats').select('*').single(),
    supabase.from('roue_lots').select('*').order('position'),
    supabase.from('roue_participations').select('*, roue_lots(nom)').eq('gagne', true).order('created_at', { ascending: false }),
    supabase.from('roue_participations').select('lot_id').not('lot_id', 'is', null).is('annulee_le', null),
  ]);
  const m = module as ModuleAccueil | null;
  if (!m) {
    return <div className="panel"><h2>Module absent</h2><p>Exécutez <code>supabase/roue.sql</code> dans Supabase pour créer la Roue de la Rentrée.</p></div>;
  }
  const pris: Record<string, number> = {};
  for (const a of attribs ?? []) pris[a.lot_id!] = (pris[a.lot_id!] ?? 0) + 1;

  return (
    <>
      <div className="adm-h">
        <div><h1>🎡 Roue de la Rentrée</h1><p>Jeu événementiel intégré à la page d&apos;accueil.</p></div>
      </div>
      <CarteRoue module={m} visible={roueVisible(m)} stats={(stats ?? {}) as Partial<StatsRoue>} onglet={onglet} />

      {onglet === 'apercu' && <TestRoue config={configRoue(m)} />}
      {onglet === 'parametres' && <FormModuleRoue module={m} config={configRoue(m)} />}
      {onglet === 'lots' && <GestionLotsRoue lots={(lots ?? []) as LotRoue[]} pris={pris} />}
      {onglet === 'gagnants' && <TableGagnants lignes={(gagnants ?? []) as ParticipationRoue[]} />}
    </>
  );
}
