import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import { dateLongue } from '@/lib/format';
import PointageListe from '@/components/PointageListe';

export const dynamic = 'force-dynamic';

export default async function Pointage(
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const { supabase } = await requireAdmin('reservations');

  const { data: evt } = await supabase
    .from('evenements')
    .select('id, titre, date_debut, lieu, heure_debut, couleur')
    .eq('id', id)
    .maybeSingle();

  if (!evt) notFound();

  const { data: resas } = await supabase
    .from('reservations')
    .select('id, nom, email, telephone, commentaire, places, places_arrivees, code_billet, reference')
    .eq('evenement_id', id)
    .eq('statut', 'payee')
    .order('nom');

  return (
    <div className="ptg-page" style={{ ['--evt' as string]: evt.couleur }}>
      <header className="ptg-entete">
        <Link href="/admin/reservations" className="ptg-retour">← Réservations</Link>
        <h1>{evt.titre}</h1>
        <p>
          {dateLongue(evt.date_debut)}
          {evt.heure_debut && ` · ${evt.heure_debut}`}
          {evt.lieu && ` · ${evt.lieu}`}
        </p>
      </header>

      <PointageListe reservations={(resas ?? []) as any} />
    </div>
  );
}
