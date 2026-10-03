import { requireAdmin } from '@/lib/supabase/server';
import { getThemes } from '@/lib/theme/db';
import { themeDuJour } from '@/lib/theme/types';
import GestionThemes from '@/components/theme/GestionThemes';

export const dynamic = 'force-dynamic';

export default async function AdminTheme() {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return <div className="panel"><h2>Accès réservé aux admins</h2></div>;

  const themes = await getThemes();
  const enLigne = themeDuJour(themes);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Thème de l&apos;accueil</h1>
          <p>Habille la page d&apos;accueil le temps d&apos;un mois ou d&apos;une fête, puis revient à la normale tout seul.</p>
        </div>
      </div>
      <div className={`msg ${enLigne ? 'ok' : ''}`} style={enLigne ? undefined : { background: '#fff' }}>
        {enLigne
          ? `En ligne en ce moment : ${enLigne.nom}.`
          : 'Aucun thème en ligne : la page d\u2019accueil a son apparence habituelle.'}
      </div>
      <GestionThemes themes={themes} annee={new Date().getFullYear()} />
    </>
  );
}
