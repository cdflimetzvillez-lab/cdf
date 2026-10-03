'use client';
import { useEffect, useState, useTransition } from 'react';
import {
  marquerScanne, changerStatutResa, supprimerReservation, verifierSumUpAdmin, encaisserReservation,
} from '@/app/reservation-actions';
import Confirmation from '@/components/Confirmation';

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);

const LIBELLES: Record<string, string> = {
  en_attente: 'En attente', payee: 'Payée', echouee: 'Échouée',
  expiree: 'Expirée', remboursee: 'Remboursée', annulee: 'Annulée',
};
const MODES: Record<string, string> = { especes: 'Espèces', cheque: 'Chèque' };
/** Statuts depuis lesquels un paiement en espèces ou par chèque peut être enregistré. */
const ENCAISSABLES = ['en_attente', 'echouee', 'expiree'];

export default function LigneReservation({ resa }: { resa: any }) {
  const [pending, start] = useTransition();
  const [confirme, setConfirme] = useState(false);
  const [verif, setVerif] = useState('');
  const [statut, setStatut] = useState<string>(resa.statut);
  const [encaisse, setEncaisse] = useState(false);
  const [mode, setMode] = useState('especes');
  const [ref, setRef] = useState('');

  // Le statut peut changer côté serveur (encaissement, vérification SumUp).
  useEffect(() => { setStatut(resa.statut); }, [resa.statut]);

  return (
    <>
      <tr style={{ opacity: pending ? .5 : 1 }}>
        <td data-l="Acheteur" className="bloc">
          <strong>{resa.nom}</strong>
          {resa.exposant && <> <span className="pill done">Exposant</span></>}
          {resa.email && (
            <><br /><a href={`mailto:${resa.email}`} style={{ color: '#6b6560', fontSize: '.8rem' }}>
              {resa.email}
            </a></>
          )}
          {resa.telephone && (
            <><br /><span style={{ color: '#6b6560', fontSize: '.8rem' }}>{resa.telephone}</span></>
          )}
          {resa.commentaire && (
            <><br /><span style={{ color: '#8a7f6f', fontSize: '.78rem', fontStyle: 'italic' }}>
              {resa.commentaire}
            </span></>
          )}
          {resa.saisie_par && (
            <><br /><span style={{ color: '#6b6560', fontSize: '.72rem' }}>Saisie par {resa.saisie_par}</span></>
          )}
        </td>
        <td data-l="Événement" style={{ fontSize: '.85rem' }}>{resa.evenements?.titre}</td>
        <td data-l="Places">
          {resa.exposant ? '' : resa.places}
          {(resa.exposant ? resa.reservation_lignes?.length > 0 : resa.reservation_lignes?.length > 1) && (
            <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>
              {resa.reservation_lignes.map((l: any, i: number) => (
                <div key={i}>{l.quantite}× {l.libelle}</div>
              ))}
            </div>
          )}
        </td>
        <td data-l="Montant">
          {euros(resa.montant_centimes)}
          {resa.mode_paiement && (
            <div style={{ marginTop: '.3rem' }}>
              <span className="pill new">{MODES[resa.mode_paiement] ?? resa.mode_paiement}</span>
              {resa.paiement_ref && (
                <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.2rem' }}>n° {resa.paiement_ref}</div>
              )}
            </div>
          )}
        </td>
        <td data-l="Billet">
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
        <td data-l="Statut">
          <select
            value={statut}
            onChange={(e) => {
              const nouveau = e.target.value;
              setStatut(nouveau);
              setVerif('');
              start(async () => {
                const r = await changerStatutResa(resa.id, nouveau);
                if (r?.erreur) { setVerif(r.erreur); setStatut(resa.statut); }
              });
            }}
            style={{ padding: '.35rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
          >
            {Object.entries(LIBELLES).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </select>
        </td>
        <td className="actions">
          {ENCAISSABLES.includes(resa.statut) && (
            <button className="btn btn-k btn-sm" style={{ marginRight: '.4rem' }} onClick={() => setEncaisse((v) => !v)}>
              Encaisser
            </button>
          )}
          {resa.statut === 'en_attente' && resa.checkout_id && (
            <button className="btn btn-y btn-sm" title="Interroger SumUp et mettre le statut à jour" style={{ marginRight: '.4rem' }}
              onClick={() => start(async () => { const r = await verifierSumUpAdmin(resa.reference); setVerif(r.changees ? 'Statut mis à jour' : 'Toujours en attente côté SumUp'); })}>
              Vérifier SumUp
            </button>
          )}
          <button className="btn btn-w btn-sm" onClick={() => setConfirme(true)}>Suppr.</button>
          {verif && <div style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.3rem' }}>{verif}</div>}
        </td>
      </tr>

      {encaisse && ENCAISSABLES.includes(resa.statut) && (
        <tr>
          <td colSpan={7} style={{ background: '#FFF6D6' }}>
            <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', alignItems: 'center' }}>
              <strong style={{ fontSize: '.9rem' }}>Encaisser {euros(resa.montant_centimes)} de {resa.nom}</strong>
              <select
                aria-label="Mode de paiement" value={mode} onChange={(e) => setMode(e.target.value)}
                style={{ padding: '.45rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
              >
                <option value="especes">Espèces</option>
                <option value="cheque">Chèque</option>
              </select>
              {mode === 'cheque' && (
                <input
                  aria-label="Numéro du chèque" placeholder="N° du chèque (facultatif)" value={ref}
                  onChange={(e) => setRef(e.target.value)}
                  style={{ padding: '.45rem .6rem', border: '2px solid var(--noir)', fontFamily: 'inherit', minWidth: 180 }}
                />
              )}
              <button
                className="btn btn-k btn-sm" disabled={pending}
                onClick={() => start(async () => {
                  const r = await encaisserReservation(resa.id, mode, mode === 'cheque' ? ref : '');
                  if (r.erreur) setVerif(r.erreur);
                  else { setEncaisse(false); setVerif('Paiement enregistré'); }
                })}
              >
                Valider le paiement
              </button>
              <button className="btn btn-w btn-sm" onClick={() => setEncaisse(false)}>Annuler</button>
            </div>
          </td>
        </tr>
      )}

      <Confirmation
        ouvert={confirme}
        danger
        titre="Supprimer cette réservation ?"
        message={`La réservation de ${resa.nom} (${resa.reference}) sera définitivement effacée.`}
        detail={resa.mode_paiement
          ? 'Le paiement a été reçu en main propre : pense à rendre la somme si besoin.'
          : 'Cela ne rembourse pas le paiement : le remboursement se fait depuis votre compte SumUp.'}
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
