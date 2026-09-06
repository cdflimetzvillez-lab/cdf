import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import EditeurMission from '@/components/tresors/EditeurMission';
import type { Mission } from '@/lib/tresors/types';

export default async function AdminMission({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { supabase } = await requireAdmin();
  let mission: Mission | null = null;
  if (id !== 'nouvelle') {
    const { data } = await supabase.from('tdn_missions').select('*').eq('id', id).maybeSingle();
    if (!data) notFound();
    mission = data as Mission;
  } else {
    const { data: max } = await supabase.from('tdn_missions').select('numero').order('numero', { ascending: false }).limit(1).maybeSingle();
    return <EditeurMission mission={null} numeroSuivant={(max?.numero ?? 0) + 1} />;
  }
  return <EditeurMission mission={mission} numeroSuivant={mission.numero} />;
}
