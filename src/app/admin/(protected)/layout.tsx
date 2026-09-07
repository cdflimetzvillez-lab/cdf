import Link from 'next/link';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import NavAdmin from '@/components/NavAdmin';
import Deconnexion from '@/components/Deconnexion';

export const dynamic = 'force-dynamic';

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const { user, isAdmin, isStaff, role } = await requireAdmin();

  // La page de login a son propre rendu : elle est exclue via son layout imbriqué.
  if (!user) redirect('/admin/login');
  if (!isStaff) {
    return (
      <div className="adm-main">
        <div className="panel">
          <h2>Compte non autorisé</h2>
          <p style={{ marginBottom: '1rem' }}>
            Votre compte ({user.email}) n&apos;est pas déclaré comme administrateur.
            Ajoutez-le dans la table <code>admins</code> de Supabase.
          </p>
          <Deconnexion />
        </div>
      </div>
    );
  }

  // Un trésorier ne voit que l'espace trésorerie (lecture seule).
  if (!isAdmin) {
    const path = (await headers()).get('x-pathname') ?? '';
    if (path && !path.startsWith('/admin/tresorerie')) redirect('/admin/tresorerie');
  }

  return (
    <div className="adm">
      <aside className="adm-side">
        <div className="brand">Comité des Fêtes<br />{isAdmin ? 'Back-office' : 'Trésorerie'}</div>
        <NavAdmin role={role ?? 'admin'} />
        <div className="sep">
          <Link href="/" target="_blank" style={{ fontSize: '.8rem' }}>↗ Voir le site</Link>
          <Deconnexion />
        </div>
      </aside>
      <main className="adm-main">{children}</main>
    </div>
  );
}
