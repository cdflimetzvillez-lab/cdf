import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import Tirage from '@/components/tresors/Tirage';
import { lireReglages } from '@/lib/tresors/db';

/** Écran grand format du tirage du grand trésor. Réservé aux administrateurs connectés. */
export default async function PageTirage() {
  const { user, isAdmin } = await requireAdmin();
  if (!user || !isAdmin) redirect('/admin/login');
  const db = createAdminClient();
  const [r, { data: cles }] = await Promise.all([
    lireReglages(),
    db.from('tdn_cles').select('id, numero, tdn_participants(prenom, tdn_comptes(prenom, nom))').order('numero'),
  ]);
  const liste = (cles ?? []).map((c) => {
    const p = c.tdn_participants as unknown as { prenom: string; tdn_comptes: { prenom: string; nom: string } | null } | null;
    return { id: c.id, numero: c.numero, prenom: p?.prenom ?? '', famille: p?.tdn_comptes ? `${p.tdn_comptes.prenom} ${p.tdn_comptes.nom}` : '' };
  });
  return <Tirage cles={liste} lot={`${r.grand_tresor_texte} de ${r.grand_tresor_montant}`} tirageFait={!!r.tirage_cle_id} />;
}
