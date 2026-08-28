'use client';
import { useState, useTransition } from 'react';
import { marquerScanne, changerStatutResa, supprimerReservation } from '@/app/reservation-actions';
import Confirmation from '@/components/Confirmation';

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);

const LIBELLES: Record<string, string> = {
  en_attente: 'En attente', payee: 'Payée', echouee: 'Échouée',
  expiree: 'Expirée', remboursee: 'Remboursée', annulee: 'Annulée',
};

export default function LigneReservation({ resa }: { resa: any }) {
  const [pending, start] = useTransition();
  const [confirme, setConfirme] = useState(false);

  return (
    <>
      <tr style={{ opacity: pending ? .5 : 1 }}>
        <td>
          <strong>{resa.nom}</strong><br />
          <a href={`mailto:${resa.email}`} style={{ color: '#6b6560', fontSize: '.8rem' }}>
            {resa.email}
          </a>
          {resa.telephone && (
            <><br /><span style={{ color: '#6b6560', fontSize: '.8rem' }}>{resa.telephone}</span></>
          )}
          {resa.commentaire && (
            <><br /><span style={{ color: '#8a7f6f', fontSize: '.78rem', fontStyle: 'italic' }}>
              {resa.commentaire}
            </span></>
          )}
        </td>
        <td style={{ fontSize: '.85rem' }}>{resa.evenements?.titre}</td>
        <td>
          {resa.places}
          {resa.reservation_lignes?.length > 1 && (
            <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>
              {resa.reservation_lignes.map((l: any, i: number) => (
                <div key={i}>{l.quantite}× {l.libelle}</div>
              ))}
            </div>
          )}
        </td>
        <td>{euros(resa.montant_centimes)}</td>
        <td>
          <code style={{ fontSize: '.8rem', fontWeight: 700 }}>{resa.code_billet}</code>
          {resa.statut === 'payee' && (
            <div style={{ marginTop: '.3rem' }}>
              {resa.scanne_le
                ? <span className="pill done">Entré</span>
                : <button
                    className="pill off" style={{ cursor: 'pointer', fontFamily: 'inherit' }}
                    onClick={() => start(() => { marquerScanne(resa.id); })}
                  >
                    Pointer
                  </button>}
            </div>
          )}
        </td>
        <td>
          <select
            defaultValue={resa.statut}
            onChange={(e) => start(() => { changerStatutResa(resa.id, e.target.value); })}
            style={{ padding: '.35rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
          >
            {Object.entries(LIBELLES).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </select>
        </td>
        <td style={{ textAlign: 'right' }}>
          <button className="btn btn-w btn-sm" onClick={() => setConfirme(true)}>Suppr.</button>
        </td>
      </tr>

      <Confirmation
        ouvert={confirme}
        danger
        titre="Supprimer cette réservation ?"
        message={`La réservation de ${resa.nom} (${resa.reference}) sera définitivement effacée.`}
        detail="Cela ne rembourse pas le paiement : le remboursement se fait depuis votre compte SumUp."
        libelleConfirmer="Supprimer"
        onAnnuler={() => setConfirme(false)}
        onConfirmer={() => {
          setConfirme(false);
          start(() => { supprimerReservation(resa.id); });
        }}
      />
    </>
  );
}
