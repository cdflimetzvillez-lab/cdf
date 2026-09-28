import { NextResponse, type NextRequest } from 'next/server';
import { traiterFile } from '@/lib/pere-noel/pipeline';

export const maxDuration = 60;
export const dynamic = 'force-dynamic';

/**
 * Passage périodique : vérifie les vidéos en cours chez HeyGen et, si la génération
 * automatique est activée, lance les commandes payées en attente.
 * Appelé par le cron Vercel (vercel.json) avec l'en-tête Authorization: Bearer CRON_SECRET,
 * ou à la main : /api/pere-noel/cron?secret=CRON_SECRET
 */
export async function GET(request: NextRequest) {
  const secret = process.env.CRON_SECRET;
  const auth = request.headers.get('authorization');
  const ok = !secret || auth === `Bearer ${secret}` || request.nextUrl.searchParams.get('secret') === secret;
  if (!ok) return NextResponse.json({ erreur: 'non autorisé' }, { status: 401 });
  try {
    const res = await traiterFile(5);
    return NextResponse.json({ ok: true, ...res });
  } catch (e: any) {
    console.error('[pere-noel cron]', e);
    return NextResponse.json({ erreur: String(e?.message ?? e) }, { status: 500 });
  }
}
