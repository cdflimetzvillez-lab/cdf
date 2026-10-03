'use client';
import { useActionState, useEffect, useMemo, useState } from 'react';
import { ajouterReservationManuelle, type EtatManuel } from '@/app/reservation-actions';

type Evt = { id: string; titre: string; prix_centimes: number | null; places_max: number | null };
type Tarif = { id: string; evenement_id: string; libelle: string; prix_centimes: number };

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);
const enSaisie = (c: number) => (c / 100).toFixed(2).replace('.', ',');

/** Ajout d'un participant par un admin : paiement en espèces, par chèque ou à venir. */
export default function FormReservationManuelle({
  evenements, tarifs, evenementInitial,
}: { evenements: Evt[]; tarifs: Tarif[]; evenementInitial?: string }) {
  const [ouvert, setOuvert] = useState(false);
  const [evenementId, setEvenementId] = useState(
    evenements.some((e) => e.id === evenementInitial) ? evenementInitial! : evenements[0]?.id ?? ''
  );
  const [qtes, setQtes] = useState<Record<string, number>>({});
  const [montantSaisi, setMontantSaisi] = useState<string | null>(null);
  const [paiement, setPaiement] = useState('especes');
  const [etat, action, pending] = useActionState<EtatManuel, FormData>(ajouterReservationManuelle, null);

  const evt = evenements.find((e) => e.id === evenementId);
  // Sans grille de tarifs, une seule ligne au prix de l'événement.
  const lignes = useMemo(() => {
    const grille = tarifs.filter((t) => t.evenement_id === evenementId);
    return grille.length > 0
      ? grille.map((t) => ({ id: t.id, libelle: t.libelle, prix: t.prix_centimes }))
      : [{ id: 'defaut', libelle: 'Place', prix: evt?.prix_centimes ?? 0 }];
  }, [tarifs, evenementId, evt]);

  const total = lignes.reduce((s, l) => s + l.prix * (qtes[l.id] ?? 0), 0);
  const places = lignes.reduce((s, l) => s + (qtes[l.id] ?? 0), 0);

  // Après un ajout réussi : on repart d'un formulaire vide, sur le même événement.
  useEffect(() => {
    if (etat?.ok) {
      setQtes({});
      setMontantSaisi(null);
    }
  }, [etat]);

  if (evenements.length === 0) return null;

  if (!ouvert) {
    return (
      <div style={{ marginBottom: '1.6rem' }}>
        {etat?.ok && <div className="msg ok">{etat.ok}</div>}
        <button type="button" className="btn btn-k btn-sm" onClick={() => setOuvert(true)}>
          + Ajouter un participant
        </button>
      </div>
    );
  }

  return (
    <div className="panel">
      <h2>Ajouter un participant</h2>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <form action={action}>
        <div className="field">
          <label htmlFor="rm-evt">Événement</label>
          <select
            id="rm-evt" name="evenement_id" value={evenementId}
            onChange={(e) => { setEvenementId(e.target.value); setQtes({}); setMontantSaisi(null); }}
          >
            {evenements.map((e) => <option key={e.id} value={e.id}>{e.titre}</option>)}
          </select>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="rm-nom">Nom et prénom</label>
            <input id="rm-nom" name="nom" required minLength={2} autoComplete="off" />
          </div>
          <div className="field">
            <label htmlFor="rm-tel">Téléphone (facultatif)</label>
            <input id="rm-tel" name="telephone" type="tel" autoComplete="off" />
          </div>
          <div className="field">
            <label htmlFor="rm-email">E-mail (facultatif)</label>
            <input id="rm-email" name="email" type="email" autoComplete="off" />
          </div>
        </div>

        <div className="field">
          <label>Places</label>
          <table className="tbl" style={{ maxWidth: 520 }}>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.id}>
                  <td>{l.libelle}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>{euros(l.prix)}</td>
                  <td style={{ width: 110 }}>
                    <input type="hidden" name="tarif_id" value={l.id} />
                    <input
                      name="tarif_qte" type="number" min={0} max={99} inputMode="numeric"
                      aria-label={`Nombre de places ${l.libelle}`}
                      value={qtes[l.id] ?? 0}
                      onChange={(e) => setQtes((q) => ({ ...q, [l.id]: Math.max(0, Math.floor(Number(e.target.value) || 0)) }))}
                      style={{ width: 90, padding: '.5rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="rm-montant">Montant ({places} place{places > 1 ? 's' : ''})</label>
            <input
              id="rm-montant" name="montant" inputMode="decimal"
              value={montantSaisi ?? enSaisie(total)}
              onChange={(e) => setMontantSaisi(e.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor="rm-paiement">Paiement</label>
            <select id="rm-paiement" name="paiement" value={paiement} onChange={(e) => setPaiement(e.target.value)}>
              <option value="especes">Espèces</option>
              <option value="cheque">Chèque</option>
              <option value="attente">Pas encore payé</option>
            </select>
          </div>
          {paiement === 'cheque' && (
            <div className="field">
              <label htmlFor="rm-ref">N° du chèque (facultatif)</label>
              <input id="rm-ref" name="paiement_ref" autoComplete="off" />
            </div>
          )}
        </div>
        {montantSaisi !== null && (
          <p style={{ fontSize: '.8rem', color: '#6b6560', margin: '-.4rem 0 .9rem' }}>
            Montant modifié à la main, tarif normal {euros(total)}.{' '}
            <button type="button" onClick={() => setMontantSaisi(null)}
              style={{ background: 'none', border: 'none', textDecoration: 'underline', cursor: 'pointer', fontFamily: 'inherit', fontSize: 'inherit', padding: 0 }}>
              Revenir au tarif normal
            </button>
          </p>
        )}

        <div className="field">
          <label htmlFor="rm-com">Remarque (facultatif)</label>
          <input id="rm-com" name="commentaire" autoComplete="off" />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '.5rem', marginBottom: '1.1rem', fontSize: '.9rem' }}>
          {paiement !== 'attente' && (
            <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
              <input type="checkbox" name="envoyer_billet" defaultChecked style={{ width: 'auto' }} />
              Envoyer le billet par e-mail (si une adresse est saisie)
            </label>
          )}
          {evt?.places_max != null && (
            <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
              <input type="checkbox" name="depasser" style={{ width: 'auto' }} />
              Autoriser le dépassement de la jauge
            </label>
          )}
        </div>

        <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
          <button className="btn btn-k btn-sm" disabled={pending || places < 1}>
            {pending ? 'Enregistrement…' : 'Ajouter la réservation'}
          </button>
          <button type="button" className="btn btn-w btn-sm" onClick={() => setOuvert(false)}>Fermer</button>
        </div>
      </form>
    </div>
  );
}
