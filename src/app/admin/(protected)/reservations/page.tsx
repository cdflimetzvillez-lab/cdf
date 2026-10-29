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
  const { supabase } = await requireAdmin('reservations');

  // Tous les événements : un exposant peut être saisi sur un événement sans billetterie.
  const [{ data: evenements }, { data: suivi }, { data: tarifs }, { data: formules }, { count: nbAttente }] = await Promise.all([
    supabase.from('evenements')
      .select('id, titre, slug, places_max, prix_centimes, billetterie_active')
      .order('date_debut'),
    supabase.from('suivi_billetterie').select('*'),
    supabase.from('tarifs').select('id, evenement_id, libelle, prix_centimes').order('position'),
    supabase.from('formules_exposants').select('id, evenement_id, libelle, prix_centimes').order('position'),
    supabase.from('liste_attente').select('id', { count: 'exact', head: true }).eq('statut', 'en_attente'),
  ]);

  let requete = supabase
    .from('reservations')
    .select('*, evenements(titre, slug), reservation_lignes(libelle, prix_centimes, quantite)')
    .order('created_at', { ascending: false });
  if (evt) requete = requete.eq('evenement_id', evt);

  const { data: resas } = await requete;
  const liste = resas ?? [];

  const payees = liste.filter((r) => r.statut === 'payee' && !r.benevole);
  const exposants = liste.filter((r) => r.exposant);
  // Repas offerts aux bénévoles : 0 €, mais à commander au traiteur.
  const benevoles = liste.filter((r) => r.benevole && r.statut === 'payee');
  const repasBenevoles = benevoles.reduce((s, r) => s + r.places, 0);
  // Saisies à la main pas encore payées : la place est prise, le montant reste à encaisser.
  const aEncaisser = liste.filter((r) => r.statut === 'en_attente' && r.saisie_par);
  const ecart = aEncaisser.reduce((s, r) => s + r.montant_centimes, 0);
  const placesAEncaisser = aEncaisser.reduce((s, r) => s + r.places, 0);
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
          <Link className={`btn btn-sm ${(nbAttente ?? 0) > 0 ? 'btn-y' : 'btn-w'}`} href="/admin/liste-attente">
            Liste d&apos;attente{(nbAttente ?? 0) > 0 ? ` (${nbAttente})` : ''}
          </Link>
          <VerifierSumUp nb={liste.filter((r) => r.statut === 'en_attente' && r.checkout_id).length} />
          <ExportCsv reservations={liste} evenements={evenements ?? []} />
        </div>
      </div>

      <FormReservationManuelle
        evenements={evenements ?? []} tarifs={tarifs ?? []} formules={formules ?? []} evenementInitial={evt}
      />

      <div className="kpi">
        <div><b>{placesVendues + placesAEncaisser + repasBenevoles}</b><span>Places réservées</span></div>
        {repasBenevoles > 0 && (
          <div><b>{repasBenevoles}</b><span>Repas offerts</span></div>
        )}
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div>
          <b style={ecart > 0 ? { color: 'var(--evt-dark)' } : undefined}>{ecart > 0 ? `− ${euros(ecart)}` : euros(0)}</b>
          <span>Écart à encaisser</span>
        </div>
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
                <th>Événement</th><th>Réservées</th><th>Jauge</th>
                <th>Encaissé</th><th>Écart</th><th></th>
              </tr>
            </thead>
            <tbody>
              {(suivi as any[]).map((s) => {
                // Jauge : places payées + places saisies à la main en attente de paiement.
                const attente = Number(s.places_a_encaisser ?? 0);
                const offerts = Number(s.places_benevoles ?? 0);
                // places_vendues inclut déjà les repas offerts (statut payée à 0 €).
                const reservees = Number(s.places_vendues) + attente;
                const du = Number(s.a_encaisser_centimes ?? 0);
                return (
                <tr key={s.id}>
                  <td data-l="Événement" className="bloc">
                    <strong>{s.titre}</strong>
                    {Number(s.nb_exposants ?? 0) > 0 && (
                      <div style={{ fontSize: '.72rem', color: '#6b6560' }}>
                        dont {s.nb_exposants} exposant{s.nb_exposants > 1 ? 's' : ''}
                      </div>
                    )}
                  </td>
                  <td data-l="Réservées">
                    {reservees}
                    {attente > 0 && (
                      <div style={{ fontSize: '.72rem', color: '#6b6560' }}>dont {attente} à encaisser</div>
                    )}
                    {offerts > 0 && (
                      <div style={{ fontSize: '.72rem', color: '#6b6560' }}>dont {offerts} repas offert{offerts > 1 ? 's' : ''}</div>
                    )}
                  </td>
                  <td data-l="Jauge" className="bloc">
                    {s.places_max
                      ? <>{reservees} / {s.places_max}
                          <div className="jauge">
                            <span style={{
                              width: `${Math.min(100, (reservees / s.places_max) * 100)}%`,
                            }} />
                          </div>
                        </>
                      : 'illimitée'}
                  </td>
                  <td data-l="Encaissé">{euros(s.recette_centimes)}</td>
                  <td data-l="Écart">
                    {du > 0
                      ? <strong style={{ color: 'var(--evt-dark)' }}>− {euros(du)}</strong>
                      : euros(0)}
                  </td>
                  <td className="actions">
                    <Link className="btn btn-y btn-sm" href={`/admin/pointage/${s.id}`}>
                      Pointer
                    </Link>{' '}
                    <Link className="btn btn-w btn-sm" href={`/admin/reservations?evt=${s.id}`}>
                      Détail
                    </Link>
                  </td>
                </tr>
                );
              })}
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

        <ListeReservations reservations={liste as any[]} tarifs={tarifs ?? []} formules={formules ?? []} />
      </div>
    </>
  );
}
