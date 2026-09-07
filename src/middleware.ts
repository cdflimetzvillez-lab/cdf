import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

type CookieToSet = { name: string; value: string; options?: CookieOptions };

export async function middleware(request: NextRequest) {
  // Le layout admin lit ce header pour connaître la page demandée (rôle trésorier).
  request.headers.set('x-pathname', request.nextUrl.pathname);
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (list: CookieToSet[]) => {
          list.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          list.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();
  const path = request.nextUrl.pathname;

  // --- garde d'accès au back-office ---
  if (path.startsWith('/admin') && !path.startsWith('/admin/login') && !user) {
    const url = request.nextUrl.clone();
    url.pathname = '/admin/login';
    url.searchParams.set('next', path);
    return NextResponse.redirect(url);
  }

  // --- mode maintenance ---
  const publique =
    !path.startsWith('/admin') &&
    !path.startsWith('/api') &&
    !path.startsWith('/maintenance') &&
    !path.startsWith('/_next');

  if (publique) {
    const { data: reglages } = await supabase
      .from('site_settings')
      .select('maintenance_active')
      .eq('id', 1)
      .maybeSingle();

    if (reglages?.maintenance_active) {
      // Un admin connecté continue de voir le site normalement,
      // pour vérifier son travail avant de rouvrir.
      let estAdmin = false;
      if (user) {
        const { data } = await supabase
          .from('admins').select('id').eq('id', user.id).maybeSingle();
        estAdmin = !!data;
      }

      if (!estAdmin) {
        const url = request.nextUrl.clone();
        url.pathname = '/maintenance';
        url.search = '';
        // rewrite et non redirect : l'URL visitée reste inchangée,
        // ce qui évite que les moteurs indexent /maintenance.
        return NextResponse.rewrite(url);
      }
    }
  }

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|webp)$).*)'],
};