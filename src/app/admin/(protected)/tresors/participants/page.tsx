import { requireAdmin } from '@/lib/supabase/server';
import TableParticipants from '@/components/tresors/TableParticipants';

export default async function AdminParticipants() {
  const { supabase } = await requireAdmin();
  const [{ data: parts }, { data: prog }, { data: cles }, { count: nbMissions }] = await Promise.all([
    supabase.from('tdn_participants').select('*, tdn_comptes(prenom, nom, email, telephone)').order('created_at', { ascending: false }),
    supabase.from('tdn_progressions').select('participant_id'),
    supabase.from('tdn_cles').select('participant_id, numero, revelee_le'),
    supabase.from('tdn_missions').select('id', { count: 'exact', head: true }).eq('publie', true),
  ]);
  const progression: Record<string, number> = {};
  for (const p of prog ?? []) progression[p.participant_id] = (progression[p.participant_id] ?? 0) + 1;
  const lignes = (parts ?? []).map((p) => {
    const c = (cles ?? []).find((k) => k.participant_id === p.id);
    const compte = p.tdn_comptes as { prenom: string; nom: string; email: string; telephone: string | null } | null;
    return {
      id: p.id, prenom: p.prenom, categorie: p.categorie, paye: p.paye,
      responsable: compte ? `${compte.prenom} ${compte.nom}` : '', email: compte?.email ?? '', telephone: compte?.telephone ?? '',
      progression: progression[p.id] ?? 0, cle: c?.numero ?? null,
      statut: !p.paye ? 'non payé' : c?.revelee_le ? 'révélé' : c ? 'terminé' : (progression[p.id] ?? 0) > 0 ? 'en cours' : 'inscrit',
    };
  });
  return (
    <>
      <div className="adm-h"><div><h1>Participants</h1><p>{lignes.filter((l) => l.paye).length} inscrits payés sur {lignes.length}.</p></div></div>
      <TableParticipants lignes={lignes} nbMissions={nbMissions ?? 0} />
    </>
  );
}
