import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';

type CookieToSet = { name: string; value: string; options?: CookieOptions };

export type RoleAdmin = 'admin' | 'tresorier';

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

/**
 * Vérifie l'utilisateur courant.
 * - isAdmin : rôle 'admin' uniquement (droits d'écriture)
 * - isStaff : admin ou trésorier (lecture)
 */
export async function requireAdmin() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { supabase, user: null, isAdmin: false, isStaff: false, role: null as RoleAdmin | null };
  const { data } = await supabase.from('admins').select('id, role').eq('id', user.id).maybeSingle();
  const role = (data?.role as RoleAdmin | undefined) ?? (data ? 'admin' : null);
  return { supabase, user, isAdmin: role === 'admin', isStaff: !!role, role };
}