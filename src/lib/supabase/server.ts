import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { createAdminClient } from '@/lib/supabase/admin';
import { MODULES_FINANCES, TOUS_LES_MODULES, type ModuleCle } from '@/lib/bureau/modules';

type CookieToSet = { name: string; value: string; options?: CookieOptions };

export type RoleAdmin = 'admin' | 'tresorier' | 'membre';

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (list: CookieToSet[]) => {
          try {
            list.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // appelé depuis un Server Component : le middleware rafraîchit
          }
        },
      },
    }
  );
}

type Membre = {
  role: RoleAdmin;
  nom: string | null;
  poste: string | null;
  posteLibelle: string | null;
  modules: string[];
};

/**
 * Fiche du membre connecté : rôle, poste et modules accordés à ce poste.
 * Tant que supabase/bureau.sql n'a pas été exécuté, on retombe sur l'ancien fonctionnement
 * (admin = tout, trésorier = trésorerie et comptabilité).
 */
async function lireMembre(supabase: Awaited<ReturnType<typeof createClient>>, userId: string): Promise<Membre | null> {
  try {
    const db = createAdminClient();
    const { data, error } = await db
      .from('admins').select('role, nom, poste, actif').eq('id', userId).maybeSingle();
    if (!error) {
      if (!data || data.actif === false) return null;
      const role = ((data.role as RoleAdmin | null) ?? 'admin');
      if (role === 'admin') {
        return { role, nom: data.nom, poste: null, posteLibelle: 'Administrateur', modules: [...TOUS_LES_MODULES] };
      }
      const { data: poste } = data.poste
        ? await db.from('bureau_postes').select('libelle, modules').eq('cle', data.poste).maybeSingle()
        : { data: null };
      // Un ancien compte « trésorier » sans poste garde au minimum ses deux modules.
      const modules = (poste?.modules as string[] | undefined) ?? (role === 'tresorier' ? [...MODULES_FINANCES] : []);
      return { role, nom: data.nom, poste: data.poste, posteLibelle: poste?.libelle ?? null, modules };
    }
  } catch {
    // clé de service absente ou base pas encore à jour : ancien fonctionnement ci-dessous
  }

  const { data } = await supabase.from('admins').select('id, role').eq('id', userId).maybeSingle();
  if (!data) return null;
  const role = ((data.role as RoleAdmin | null) ?? 'admin');
  return {
    role, nom: null, poste: null, posteLibelle: null,
    modules: role === 'admin' ? [...TOUS_LES_MODULES] : [...MODULES_FINANCES],
  };
}

/**
 * Vérifie l'utilisateur courant et ses droits.
 *
 * Sans argument (comptabilité, trésorerie, layout) :
 * - isAdmin : administrateur uniquement
 * - isStaff : administrateur, ou membre ayant la trésorerie ou la comptabilité
 *
 * Avec un module : isAdmin et isStaff valent vrai si le poste du membre donne accès à ce module.
 * Le client renvoyé peut alors écrire dans les tables du module, les règles de la base
 * restant réservées aux administrateurs. Toujours passer le module de la page ou de l'action :
 * c'est ce contrôle, côté serveur, qui cloisonne les modules entre eux.
 */
export async function requireAdmin(module?: ModuleCle) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const rien = {
    supabase, user: user ?? null, isAdmin: false, isStaff: false, superAdmin: false, membre: false,
    role: null as RoleAdmin | null, poste: null as string | null, posteLibelle: null as string | null,
    nom: null as string | null, modules: [] as string[],
  };
  if (!user) return rien;

  const m = await lireMembre(supabase, user.id);
  if (!m) return rien;

  const superAdmin = m.role === 'admin';
  const base = {
    user, superAdmin, membre: true, role: m.role, poste: m.poste, posteLibelle: m.posteLibelle,
    nom: m.nom, modules: m.modules,
  };

  if (!module) {
    const finances = superAdmin || m.modules.some((x) => (MODULES_FINANCES as string[]).includes(x));
    return { ...base, supabase, isAdmin: superAdmin, isStaff: finances };
  }

  // « bureau » n'est jamais attribuable à un poste.
  const acces = superAdmin || (module !== 'bureau' && m.modules.includes(module));
  // Trésorerie et comptabilité : la base contrôle déjà via is_staff(), on garde le client du membre.
  const elever = acces && !superAdmin && !(MODULES_FINANCES as string[]).includes(module);
  return {
    ...base,
    supabase: elever ? (createAdminClient() as unknown as typeof supabase) : supabase,
    isAdmin: acces,
    isStaff: acces,
  };
}
