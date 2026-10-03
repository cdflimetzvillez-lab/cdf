import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import ExportCsv from '@/components/ExportCsv';
import ListeReservationsLecture from '@/components/ListeReservationsLecture';

export const dynamic = 'force-dynamic';

export default async function Tresorerie({ searchParams }: { searchParams: Promise<{ evt?: string }> }) {
  const { evt } = await searchParams;
  const { supabase } = await requireAdmin();

  const [{ data: evenements }, { data: suivi }] = await Promise.all([
    supabase.from('evenements').select('id, titre, slug, places_max, prix_centimes').order('date_debut'),
    supabase.from('suivi_billetterie').select('*'),
  ]);

  let requete = supabase
    .from('reservations')
    .select('*, evenements(titre, slug), reservation_lignes(libelle, prix_centimes, quantite)')
    .order('created_at', { ascending: false });
  if (evt) requete = requete.eq('evenement_id', evt);
  const { data: resas } = await requete;
  const liste = resas ?? [];

  const payees = liste.filter((r) => r.statut === 'payee');
  const recette = payees.reduce((s, r) => s + r.montant_centimes, 0);
  const placesVendues = payees.reduce((s, r) => s + r.places, 0);
  // Saisies à la main pas encore payées : la place est prise, le montant reste à encaisser.
  const aEncaisser = liste.filter((r) => r.statut === 'en_attente' && r.saisie_par);
  const ecart = aEncaisser.reduce((s, r) => s + r.montant_centimes, 0);
  const placesAEncaisser = aEncaisser.reduce((s, r) => s + r.places, 0);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Trésorerie</h1>
          <p>Consultation des réservations et des recettes : SumUp, espèces, chèques (lecture seule).</p>
        </div>
        <ExportCsv reservations={liste} evenements={evenements ?? []} />
      </div>

      <div className="kpi">
        <div><b>{placesVendues + placesAEncaisser}</b><span>Places réservées</span></div>
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div>
          <b style={ecart > 0 ? { color: 'var(--evt-dark)' } : undefined}>{ecart > 0 ? `− ${euros(ecart)}` : euros(0)}</b>
          <span>Écart à encaisser</span>
        </div>
        <div><b>{payees.length}</b><span>Réservations payées</span></div>
        <div><b>{liste.filter((r) => r.statut === 'en_attente').length}</b><span>En attente</span></div>
      </div>

      {(suivi ?? []).length > 0 && (
        <div className="panel">
          <h2>Par événement</h2>
          <table className="tbl cartes compact">
            <thead><tr><th>Événement</th><th>Réservées</th><th>Jauge</th><th>Encaissé</th><th>Écart</th><th></th></tr></thead>
            <tbody>
              {(suivi as any[]).map((s) => {
                // Jauge : places payées + places saisies à la main en attente de paiement.
                const attente = Number(s.places_a_encaisser ?? 0);
                const reservees = Number(s.places_vendues) + attente;
                const du = Number(s.a_encaisser_centimes ?? 0);
                return (
                <tr key={s.id}>
                  <td data-l="Événement" className="bloc">
                    <strong>{s.titre}</strong>
                    {Number(s.nb_exposants ?? 0) > 0 && (
                      <div style={{ fontSize: '.72rem', color: '#6b6560' }}>dont {s.nb_exposants} exposant{s.nb_exposants > 1 ? 's' : ''}</div>
                    )}
                  </td>
                  <td data-l="Réservées">
                    {reservees}
                    {attente > 0 && <div style={{ fontSize: '.72rem', color: '#6b6560' }}>dont {attente} à encaisser</div>}
                  </td>
                  <td data-l="Jauge" className="bloc">
                    {s.places_max
                      ? <>{reservees} / {s.places_max}
                          <div className="jauge"><span style={{ width: `${Math.min(100, (reservees / s.places_max) * 100)}%` }} /></div>
                        </>
                      : 'illimitée'}
                  </td>
                  <td data-l="Encaissé">{euros(s.recette_centimes)}</td>
                  <td data-l="Écart">
                    {du > 0 ? <strong style={{ color: 'var(--evt-dark)' }}>− {euros(du)}</strong> : euros(0)}
                  </td>
                  <td className="actions">
                    <Link className="btn btn-w btn-sm" href={`/admin/tresorerie?evt=${s.id}`}>Détail</Link>
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
          {evt ? `Réservations — ${evenements?.find((e) => e.id === evt)?.titre ?? ''}` : 'Toutes les réservations'}
          {evt && <> · <Link href="/admin/tresorerie" style={{ fontSize: '.8rem' }}>tout voir</Link></>}
        </h2>
        <ListeReservationsLecture reservations={liste as any[]} />
      </div>
    </>
  );
}
