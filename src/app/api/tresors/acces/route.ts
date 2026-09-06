import { NextResponse, type NextRequest } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { COOKIE_TOKEN } from '@/lib/tresors/db';

/** Lien d'accès reçu par e-mail : pose le cookie et renvoie vers l'aventure. */
export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get('token') ?? '';
  const base = request.nextUrl.origin;
  if (!/^[0-9a-f-]{36}$/i.test(token)) return NextResponse.redirect(`${base}/tresors-de-noel/acces?erreur=1`);

  const db = createAdminClient();
  const { data } = await db.from('tdn_comptes').select('id').eq('token', token).maybeSingle();
  if (!data) return NextResponse.redirect(`${base}/tresors-de-noel/acces?erreur=1`);

  const res = NextResponse.redirect(`${base}/tresors-de-noel/aventure`);
  res.cookies.set(COOKIE_TOKEN, token, { httpOnly: true, sameSite: 'lax', secure: process.env.NODE_ENV === 'production', maxAge: 60 * 60 * 24 * 365, path: '/' });
  return res;
}
