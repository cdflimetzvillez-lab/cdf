import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import LigneAttente from '@/components/LigneAttente';
import type { ListeAttente } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function ListeAttentePage() {
  const { supabase } = await requireAdmin('reservations');
  const { data } = await supabase.from('liste_attente')
    .select('*, evenements(titre, slug)')
    .order('created_at', { ascending: true });
  const liste = (data ?? []) as ListeAttente[];

  // Regroupement par événement, dans l'ordre d'inscription.
  const parEvenement = new Map<string, { titre: string; lignes: ListeAttente[] }>();
  for (const l of liste) {
    const g = parEvenement.get(l.evenement_id) ?? { titre: l.evenements?.titre ?? 'Événement', lignes: [] };
    g.lignes.push(l);
    parEvenement.set(l.evenement_id, g);
  }
  const enAttente = liste.filter((l) => l.statut === 'en_attente');
  const placesAttendues = enAttente.reduce((s, l) => s + l.places, 0);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Liste d&apos;attente</h1>
          <p>
            {enAttente.length} personne{enAttente.length > 1 ? 's' : ''} en attente
            {placesAttendues > 0 && ` pour ${placesAttendues} place${placesAttendues > 1 ? 's' : ''}`}.
            {' '}À contacter dans l&apos;ordre d&apos;inscription en cas de désistement.
          </p>
        </div>
        <Link className="btn btn-w btn-sm" href="/admin/reservations">← Réservations</Link>
      </div>

      {parEvenement.size === 0 && (
        <div className="panel">
          <p style={{ color: '#6b6560' }}>
            Personne sur liste d&apos;attente pour le moment. Elle s&apos;active dans la fiche d&apos;un événement
            (case « Proposer une liste d&apos;attente quand l&apos;événement est complet »).
          </p>
        </div>
      )}

      {[...parEvenement.entries()].map(([evtId, g]) => {
        const attente = g.lignes.filter((l) => l.statut === 'en_attente');
        const places = attente.reduce((s, l) => s + l.places, 0);
        return (
          <div className="panel" key={evtId}>
            <h2>
              {g.titre}
              <span style={{ fontSize: '.8rem', fontWeight: 400, color: '#6b6560', marginLeft: '.8rem' }}>
                {attente.length} en attente · {places} place{places > 1 ? 's' : ''}
              </span>
            </h2>
            <table className="tbl">
              <thead>
                <tr>
                  <th>#</th><th>Contact</th><th>Places</th><th>Message</th><th>Inscrit le</th>
                  <th>Statut</th><th></th>
                </tr>
              </thead>
              <tbody>
                {g.lignes.map((l, i) => <LigneAttente key={l.id} ligne={l} rang={i + 1} />)}
              </tbody>
            </table>
          </div>
        );
      })}
    </>
  );
}
