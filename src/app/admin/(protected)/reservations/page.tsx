import Link from 'next/link';
import { requireAdmin } from '@/lib/supabase/server';
import { euros } from '@/lib/sumup';
import LigneReservation from '@/components/LigneReservation';
import ExportCsv from '@/components/ExportCsv';

export const dynamic = 'force-dynamic';

export default async function Reservations({
  searchParams,
}: { searchParams: Promise<{ evt?: string }> }) {
  const { evt } = await searchParams;
  const { supabase } = await requireAdmin();

  const [{ data: evenements }, { data: suivi }] = await Promise.all([
    supabase.from('evenements')
      .select('id, titre, slug, places_max, prix_centimes')
      .eq('billetterie_active', true).order('date_debut'),
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

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>Réservations</h1>
          <p>Suivi des paiements SumUp, pointage et liste d&apos;émargement.</p>
        </div>
        <ExportCsv reservations={liste} evenements={evenements ?? []} />
      </div>

      <div className="kpi">
        <div><b>{placesVendues}</b><span>Places vendues</span></div>
        <div><b>{euros(recette)}</b><span>Recette encaissée</span></div>
        <div><b>{payees.length}</b><span>Réservations payées</span></div>
        <div><b>{liste.filter((r) => r.statut === 'en_attente').length}</b><span>En attente</span></div>
      </div>

      {(suivi ?? []).length > 0 && (
        <div className="panel">
          <h2>Par événement</h2>
          <table className="tbl">
            <thead>
              <tr>
                <th>Événement</th><th>Vendues</th><th>Jauge</th>
                <th>Recette</th><th></th>
              </tr>
            </thead>
            <tbody>
              {(suivi as any[]).map((s) => (
                <tr key={s.id}>
                  <td><strong>{s.titre}</strong></td>
                  <td>{s.places_vendues}</td>
                  <td>
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
                  <td>{euros(s.recette_centimes)}</td>
                  <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
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

      <div className="panel">
        <h2>
          {evt
            ? `Réservations — ${evenements?.find((e) => e.id === evt)?.titre ?? ''}`
            : 'Toutes les réservations'}
          {evt && <> · <Link href="/admin/reservations" style={{ fontSize: '.8rem' }}>tout voir</Link></>}
        </h2>

        <table className="tbl">
          <thead>
            <tr>
              <th>Acheteur</th><th>Événement</th><th>Places</th>
              <th>Montant</th><th>Billet</th><th>Statut</th><th></th>
            </tr>
          </thead>
          <tbody>
            {liste.map((r) => <LigneReservation key={r.id} resa={r as any} />)}
            {liste.length === 0 && (
              <tr><td colSpan={7} style={{ color: '#6b6560' }}>Aucune réservation.</td></tr>
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
