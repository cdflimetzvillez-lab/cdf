'use client';
import { useMemo, useState } from 'react';
import LigneReservation from '@/components/LigneReservation';

const norm = (s: unknown) =>
  String(s ?? '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

export default function ListeReservations({ reservations }: { reservations: any[] }) {
  const [q, setQ] = useState('');
  const liste = useMemo(() => {
    const t = norm(q).trim();
    if (!t) return reservations;
    return reservations.filter((r) =>
      [r.nom, r.email, r.telephone, r.reference, r.code_billet, r.evenements?.titre, r.commentaire]
        .some((v) => norm(v).includes(t)),
    );
  }, [q, reservations]);

  return (
    <>
      <div style={{ display: 'flex', gap: '.6rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '1rem' }}>
        <input
          type="search"
          placeholder="Rechercher un nom, e-mail, téléphone, code billet…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          style={{ flex: 1, minWidth: 200, padding: '.6rem .8rem', border: '2px solid var(--noir)', fontFamily: 'inherit', fontSize: '.9rem' }}
        />
        <span style={{ fontSize: '.78rem', color: '#6b6560', whiteSpace: 'nowrap' }}>
          {liste.length} / {reservations.length}
        </span>
      </div>

      <table className="tbl cartes compact">
        <thead>
          <tr>
            <th>Acheteur</th><th>Événement</th><th>Places</th>
            <th>Montant</th><th>Billet</th><th>Statut</th><th></th>
          </tr>
        </thead>
        <tbody>
          {liste.map((r) => <LigneReservation key={r.id} resa={r} />)}
          {liste.length === 0 && (
            <tr><td colSpan={7} style={{ color: '#6b6560' }}>{q ? 'Aucun résultat.' : 'Aucune réservation.'}</td></tr>
          )}
        </tbody>
      </table>
    </>
  );
}
