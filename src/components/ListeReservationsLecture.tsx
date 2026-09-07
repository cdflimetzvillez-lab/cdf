'use client';
import { useMemo, useState } from 'react';

const euros = (c: number) => new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);
const fmt = (iso: string) => new Intl.DateTimeFormat('fr-FR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'Europe/Paris' }).format(new Date(iso));
const LIBELLES: Record<string, string> = {
  en_attente: 'En attente', payee: 'Payée', echouee: 'Échouée', expiree: 'Expirée', remboursee: 'Remboursée', annulee: 'Annulée',
};
const CLASSE: Record<string, string> = { payee: 'on', en_attente: 'new', remboursee: 'off', annulee: 'off', echouee: 'off', expiree: 'off' };
const norm = (s: unknown) => String(s ?? '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

export default function ListeReservationsLecture({ reservations }: { reservations: any[] }) {
  const [q, setQ] = useState('');
  const liste = useMemo(() => {
    const t = norm(q).trim();
    if (!t) return reservations;
    return reservations.filter((r) =>
      [r.nom, r.email, r.telephone, r.reference, r.code_billet, r.evenements?.titre].some((v) => norm(v).includes(t)),
    );
  }, [q, reservations]);

  return (
    <>
      <div style={{ display: 'flex', gap: '.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '1rem' }}>
        <input type="search" placeholder="Rechercher un nom, e-mail, téléphone, code billet…" value={q} onChange={(e) => setQ(e.target.value)}
          style={{ flex: 1, minWidth: 200, padding: '.6rem .8rem', border: '2px solid var(--noir)', fontFamily: 'inherit', fontSize: '.9rem' }} />
        <span style={{ fontSize: '.78rem', color: '#6b6560', whiteSpace: 'nowrap' }}>{liste.length} / {reservations.length}</span>
      </div>

      <table className="tbl cartes compact">
        <thead><tr><th>Date</th><th>Acheteur</th><th>Événement</th><th>Places</th><th>Montant</th><th>Billet</th><th>Statut</th></tr></thead>
        <tbody>
          {liste.map((r) => (
            <tr key={r.id}>
              <td data-l="Date">{fmt(r.created_at)}</td>
              <td data-l="Acheteur" className="bloc">
                <strong>{r.nom}</strong><br />
                <span style={{ color: '#6b6560', fontSize: '.8rem' }}>{r.email}{r.telephone && <> · {r.telephone}</>}</span>
              </td>
              <td data-l="Événement" style={{ fontSize: '.85rem' }}>{r.evenements?.titre}</td>
              <td data-l="Places">
                {r.places}
                {r.reservation_lignes?.length > 1 && (
                  <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>
                    {r.reservation_lignes.map((l: any, i: number) => <div key={i}>{l.quantite}× {l.libelle}</div>)}
                  </div>
                )}
              </td>
              <td data-l="Montant">{euros(r.montant_centimes)}</td>
              <td data-l="Billet"><code style={{ fontSize: '.8rem', fontWeight: 700 }}>{r.code_billet}</code>{r.scanne_le && <> <span className="pill done">Entré</span></>}</td>
              <td data-l="Statut"><span className={`pill ${CLASSE[r.statut] ?? 'off'}`}>{LIBELLES[r.statut] ?? r.statut}</span></td>
            </tr>
          ))}
          {liste.length === 0 && <tr><td colSpan={7} style={{ color: '#6b6560' }}>{q ? 'Aucun résultat.' : 'Aucune réservation.'}</td></tr>}
        </tbody>
      </table>
    </>
  );
}
