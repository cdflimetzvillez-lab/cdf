import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import ListeReservations from '@/components/ListeReservations';
import ExportCsv from '@/components/ExportCsv';
import VerifierSumUp from '@/components/VerifierSumUp';
import FormReservationManuelle from '@/components/FormReservationManuelle';

export const dynamic = 'force-dynamic';

export default async function Reservations({
  searchParams,
}: { searchParams: Promise<{ evt?: string }> }) {
  const { evt } = await searchParams;
  const { supabase } = await requireAdmin();

  // Tous les événements : un exposant peut être saisi sur un événement sans billetterie.
  const [{ data: evenements }, { data: suivi }, { data: tarifs }, { data: formules }] = await Promise.all([
    supabase.from('evenements')
      .select('id, titre, slug, places_max, prix_centimes, billetterie_active')
      .order('date_debut'),
    supabase.from('suivi_billetterie').select('*'),
    supabase.from('tarifs').select('id, evenement_id, libelle, prix_centimes').order('position'),
    supabase.from('formules_exposants').select('id, evenement_id, libelle, prix_centimes').order('position'),
  ]);

  // Synthèse des exposants par événement (les événements sans billetterie n'ont pas de ligne de suivi).
  const { data: resasExposants } = await supabase
    .from('reservations').select('evenement_id, montant_centimes, statut').eq('exposant', true);
  const parExposant = (evenements ?? [])
    .map((e) => {
      const rs = (resasExposants ?? []).filter((r) => r.evenement_id === e.id);
      const payes = rs.filter((r) => r.statut === 'payee');
      return {
        id: e.id, titre: e.titre, total: rs.length, payes: payes.length,
        recette: payes.reduce((s, r) => s + r.montant_centimes, 0),
        attente: rs.filter((r) => r.statut === 'en_attente').length,
      };
    })
    .filter((e) => e.total > 0);

  let requete = supabase
    .from('reservations')
    .select('*, evenements(titre, slug), reservation_lignes(libelle, prix_centimes, quantite)')
    .order('created_at', { ascending: false });
  if (evt) requete = requete.eq('evenement_id', evt);

  const { data: resas } = await requete;
  const liste = resas ?? [];

  const payees = liste.filter((r) => r.statut === 'payee');
  const exposants = liste.filter((r) => r.exposant);
  const recette = payees.reduce((s, r) => s + r.montant_centimes, 0);
  const placesVendues = payees.reduce((s, r) => s + r.places, 0);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Réservations</h1>
          <p>Suivi des paiements (SumUp, espèces, chèques), pointage et liste d&apos;émargement.</p>
        </div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', alignItems: 'flex-start' }}>
          <VerifierSumUp nb={liste.filter((r) => r.statut === 'en_attente' && r.checkout_id).length} />
          <ExportCsv reservations={liste} evenements={evenements ?? []} />
        </div>
      </div>

      <FormReservationManuelle
        evenements={evenements ?? []} tarifs={tarifs ?? []} formules={formules ?? []} evenementInitial={evt}
      />

      <div className="kpi">
        <div><b>{placesVendues}</b><span>Places vendues</span></div>
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div><b>{payees.length}</b><span>Réservations payées</span></div>
        <div><b>{liste.filter((r) => r.statut === 'en_attente').length}</b><span>En attente</span></div>
        {exposants.length > 0 && (
          <div><b>{exposants.length}</b><span>Exposants</span></div>
        )}
      </div>

      {(suivi ?? []).length > 0 && (
        <div className="panel">
          <h2>Par événement</h2>
          <table className="tbl cartes compact">
            <thead>
              <tr>
                <th>Événement</th><th>Vendues</th><th>Jauge</th>
                <th>Recette</th><th></th>
              </tr>
            </thead>
            <tbody>
              {(suivi as any[]).map((s) => (
                <tr key={s.id}>
                  <td data-l="Événement" className="bloc"><strong>{s.titre}</strong></td>
                  <td data-l="Vendues">{s.places_vendues}</td>
                  <td data-l="Jauge" className="bloc">
                    {s.places_max
                      ? <>{s.places_vendues} / {s.places_max}
                          <div className="jauge">
                            <span style={{
                              width: `${Math.min(100, (s.places_vendues / s.places_max) * 100)}%`,
                            }} />
                          </div>
                        </>
                      : 'illimitée'}
                  </td>
                  <td data-l="Recette">{euros(s.recette_centimes)}</td>
                  <td className="actions">
                    <Link className="btn btn-y btn-sm" href={`/admin/pointage/${s.id}`}>
                      Pointer
                    </Link>{' '}
                    <Link className="btn btn-w btn-sm" href={`/admin/reservations?evt=${s.id}`}>
                      Détail
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {parExposant.length > 0 && (
        <div className="panel">
          <h2>Exposants par événement</h2>
          <table className="tbl cartes compact">
            <thead>
              <tr><th>Événement</th><th>Exposants</th><th>Payés</th><th>En attente</th><th>Recette</th><th></th></tr>
            </thead>
            <tbody>
              {parExposant.map((e) => (
                <tr key={e.id}>
                  <td data-l="Événement" className="bloc"><strong>{e.titre}</strong></td>
                  <td data-l="Exposants">{e.total}</td>
                  <td data-l="Payés">{e.payes}</td>
                  <td data-l="En attente">{e.attente}</td>
                  <td data-l="Recette">{euros(e.recette)}</td>
                  <td className="actions">
                    <Link className="btn btn-y btn-sm" href={`/admin/pointage/${e.id}`}>Pointer</Link>{' '}
                    <Link className="btn btn-w btn-sm" href={`/admin/reservations?evt=${e.id}`}>Détail</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="panel">
        <h2>
          {evt
            ? `Réservations — ${evenements?.find((e) => e.id === evt)?.titre ?? ''}`
            : 'Toutes les réservations'}
          {evt && <> · <Link href="/admin/reservations" style={{ fontSize: '.8rem' }}>tout voir</Link></>}
        </h2>

        <ListeReservations reservations={liste as any[]} />
      </div>
    </>
  );
}
