import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import Tirage from '@/components/tresors/Tirage';
import { lireReglages } from '@/lib/tresors/db';
import { clesTirees, nombreGrandTresor } from '@/lib/tresors/types';

/** Écran grand format du tirage du grand trésor (une clé gagnante par lot). Réservé aux administrateurs connectés. */
export default async function PageTirage() {
  const { user, isAdmin } = await requireAdmin('tresors');
  if (!user || !isAdmin) redirect('/admin/login');
  const db = createAdminClient();
  const [r, { data: cles }, { data: grand }] = await Promise.all([
    lireReglages(),
    db.from('tdn_cles').select('id, numero, tdn_participants(prenom, tdn_comptes(prenom, nom))').order('numero'),
    db.from('tdn_lots').select('nom').eq('grand', true).order('position').limit(1).maybeSingle(),
  ]);
  const liste = (cles ?? []).map((c) => {
    const p = c.tdn_participants as unknown as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '' };
  });
  const lot = `${r.grand_tresor_texte} de ${r.grand_tresor_montant}`;
  return <Tirage cles={liste} nombre={nombreGrandTresor(r)} lot={lot} lotUnitaire={grand?.nom ?? lot} tirageFait={clesTirees(r).length > 0} />;
}
