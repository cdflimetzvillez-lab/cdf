import { requireAdmin } from '@/lib/supabase/server';
import { createAdminClient } from '@/lib/supabase/admin';
import GestionBureau, { type MembreBureau, type PosteBureau } from '@/components/bureau/GestionBureau';

export const dynamic = 'force-dynamic';

export default async function AdminBureau() {
  const { superAdmin, user } = await requireAdmin('bureau');
  if (!superAdmin || !user) {
    return <div className="panel"><h2>Réservé aux administrateurs</h2></div>;
  }

  const db = createAdminClient();
  const [{ data: postes, error }, { data: membres }] = await Promise.all([
    db.from('bureau_postes').select('cle, libelle, modules, position').order('position'),
    db.from('admins').select('*').order('nom'),
  ]);

  if (error) {
    return (
      <div className="panel">
        <h2>Module non installé</h2>
        <p style={{ marginBottom: '.8rem' }}>
          Exécute le fichier <code>supabase/bureau.sql</code> dans l&apos;éditeur SQL du projet Supabase du CDF, puis recharge cette page.
        </p>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>{error.message}</p>
      </div>
    );
  }

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Accès du bureau</h1>
          <p>Qui a accès à l&apos;administration, et quels modules voit chaque poste.</p>
        </div>
      </div>
      <GestionBureau
        membres={(membres ?? []) as MembreBureau[]}
        postes={(postes ?? []) as PosteBureau[]}
        moi={user.id}
      />
    </>
  );
}
