import Link from 'next/link';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { moduleDuChemin, premiereChemin } from '@/lib/bureau/modules';
import NavAdmin from '@/components/NavAdmin';
import Deconnexion from '@/components/Deconnexion';

export const dynamic = 'force-dynamic';

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user, membre, superAdmin, modules, posteLibelle } = await requireAdmin();

  // La page de login a son propre rendu : elle est exclue via son layout imbriqué.
  if (!user) redirect('/admin/login');
  if (!membre) {
    return (
      <div className="adm-main">
        <div className="panel">
          <h2>Compte non autorisé</h2>
          <p style={{ marginBottom: '1rem' }}>
            Votre compte ({user.email}) n&apos;a pas accès à l&apos;administration, ou son accès a été désactivé.
            Un administrateur peut l&apos;ajouter dans « Accès du bureau ».
          </p>
          <Deconnexion />
        </div>
      </div>
    );
  }

  // Chaque membre ne voit que les modules confiés à son poste.
  if (!superAdmin) {
    const path = (await headers()).get('x-pathname') ?? '';
    const module = moduleDuChemin(path);
    if (path && (!module || !modules.includes(module))) {
      const accueil = premiereChemin(modules);
      if (accueil && accueil !== path) redirect(accueil);
      return (
        <div className="adm-main">
          <div className="panel">
            <h2>Aucun module accessible</h2>
            <p style={{ marginBottom: '1rem' }}>
              Votre poste ne donne accès à aucun module pour le moment. Un administrateur peut le régler dans « Accès du bureau ».
            </p>
            <Deconnexion />
          </div>
        </div>
      );
    }
  }

  return (
    <div className="adm">
      <aside className="adm-side">
        <div className="brand">Comité des Fêtes<br />{superAdmin ? 'Back-office' : posteLibelle ?? 'Bureau'}</div>
        <NavAdmin modules={modules} />
        <div className="sep">
          <Link href="/" target="_blank" style={{ fontSize: '.8rem' }}>↗ Voir le site</Link>
          <Deconnexion />
        </div>
      </aside>
      <main className="adm-main">{children}</main>
    </div>
  );
}
