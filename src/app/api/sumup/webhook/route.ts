import { NextResponse, type NextRequest } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { lireCheckout } from '@/lib/sumup';
import { envoyerBillet } from '@/app/reservation-actions';
import { synchroniserCommande } from '@/app/tresors-actions';

/**
 * Webhook SumUp.
 * À déclarer dans le back-office SumUp :
 *   https://votre-domaine.fr/api/sumup/webhook
 *
 * On ne fait jamais confiance au corps de la requête : on relit
 * systématiquement l'état du checkout via l'API avant d'écrire.
 */
export async function POST(request: NextRequest) {
  // Filtre optionnel par jeton partagé dans l'URL : ?jeton=xxx
  const attendu = process.env.SUMUP_WEBHOOK_TOKEN;
  if (attendu && request.nextUrl.searchParams.get('jeton') !== attendu) {
    return NextResponse.json({ erreur: 'non autorisé' }, { status: 401 });
  }

  let corps: any;
  try {
    corps = await request.json();
  } catch {
    return NextResponse.json({ erreur: 'corps invalide' }, { status: 400 });
  }

  const checkoutId: string | undefined =
    corps?.id ?? corps?.checkout_id ?? corps?.payload?.id;

  if (!checkoutId) {
    return NextResponse.json({ erreur: 'checkout_id absent' }, { status: 400 });
  }

  try {
    const checkout = await lireCheckout(checkoutId);
    const db = createAdminClient();

    const correspondance: Record<string, string> = {
      PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente',
    };
    const statut = correspondance[checkout.status] ?? 'en_attente';

    const { data: avant } = await db
      .from('reservations')
      .select('id, statut')
      .eq('checkout_id', checkoutId)
      .maybeSingle();

    if (!avant) {
      // Trésors de Noël ? (référence TDN-…)
      const cmd = await synchroniserCommande(undefined, checkoutId);
      if (cmd) return NextResponse.json({ ok: true, module: 'tresors', statut: cmd.statut });
      // Paiement inconnu : on répond 200 pour éviter que SumUp réessaie sans fin.
      console.warn('[webhook] réservation introuvable', checkoutId);
      return NextResponse.json({ ok: true, ignore: true });
    }

    if (avant.statut === statut) return NextResponse.json({ ok: true, inchange: true });

    const { data: apres } = await db
      .from('reservations')
      .update({
        statut,
        transaction_code: checkout.transaction_code
          ?? checkout.transactions?.[0]?.transaction_code
          ?? null,
        paye_le: statut === 'payee' ? new Date().toISOString() : null,
      })
      .eq('id', avant.id)
      .select('*, evenements(titre, slug, date_debut, lieu, heure_debut)')
      .single();

    if (statut === 'payee') await envoyerBillet(apres);

    return NextResponse.json({ ok: true, statut });
  } catch (e) {
    console.error('[webhook]', e);
    return NextResponse.json({ erreur: 'traitement impossible' }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({ service: 'webhook SumUp', actif: true });
}
