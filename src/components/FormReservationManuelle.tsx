'use client';
import { useActionState, useEffect, useMemo, useState, useTransition } from 'react';
import {
  ajouterReservationManuelle, ajouterFormuleExposant, supprimerFormuleExposant, type EtatManuel,
} from '@/app/reservation-actions';

type Evt = { id: string; titre: string; prix_centimes: number | null; places_max: number | null; billetterie_active: boolean | null };
type Tarif = { id: string; evenement_id: string; libelle: string; prix_centimes: number };
type TypeSaisie = 'participant' | 'exposant';

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);
const enSaisie = (c: number) => (c / 100).toFixed(2).replace('.', ',');
const champ = { padding: '.5rem', border: '2px solid var(--noir)', fontFamily: 'inherit' } as const;

/**
 * Ajout par un admin d'un participant (billetterie) ou d'un exposant (formules d'emplacement),
 * avec paiement en espèces, par chèque ou à venir.
 */
export default function FormReservationManuelle({
  evenements, tarifs, formules, evenementInitial,
}: { evenements: Evt[]; tarifs: Tarif[]; formules: Tarif[]; evenementInitial?: string }) {
  const [ouvert, setOuvert] = useState(false);
  const [type, setType] = useState<TypeSaisie>('participant');
  const [evenementId, setEvenementId] = useState('');
  const [qtes, setQtes] = useState<Record<string, number>>({});
  const [montantSaisi, setMontantSaisi] = useState<string | null>(null);
  const [paiement, setPaiement] = useState('especes');
  const [etat, action, pending] = useActionState<EtatManuel, FormData>(ajouterReservationManuelle, null);

  // Gestion des formules exposants
  const [nouveauLibelle, setNouveauLibelle] = useState('');
  const [nouveauPrix, setNouveauPrix] = useState('');
  const [erreurFormule, setErreurFormule] = useState('');
  const [enCours, start] = useTransition();

  const exposant = type === 'exposant';
  // Participants : événements avec billetterie. Exposants : tous les événements.
  const choix = useMemo(
    () => (exposant ? evenements : evenements.filter((e) => e.billetterie_active)),
    [evenements, exposant]
  );
  const evt =
    choix.find((e) => e.id === evenementId) ??
    choix.find((e) => e.id === evenementInitial) ??
    (exposant ? choix.find((e) => /march/i.test(e.titre)) : undefined) ??
    choix[0];

  const lignes = useMemo(() => {
    if (!evt) return [];
    const grille = (exposant ? formules : tarifs).filter((t) => t.evenement_id === evt.id);
    if (grille.length > 0) return grille.map((t) => ({ id: t.id, libelle: t.libelle, prix: t.prix_centimes }));
    // Sans grille : prix unique de l'événement, ou emplacement à prix libre pour un exposant.
    return [{ id: 'defaut', libelle: exposant ? 'Emplacement' : 'Place', prix: exposant ? 0 : evt.prix_centimes ?? 0 }];
  }, [tarifs, formules, evt, exposant]);
  const formulesEvt = exposant && evt ? formules.filter((f) => f.evenement_id === evt.id) : [];

  const total = lignes.reduce((s, l) => s + l.prix * (qtes[l.id] ?? 0), 0);
  const quantite = lignes.reduce((s, l) => s + (qtes[l.id] ?? 0), 0);

  const vider = () => { setQtes({}); setMontantSaisi(null); };

  // Après un ajout réussi : formulaire vide, même événement.
  useEffect(() => { if (etat?.ok) vider(); }, [etat]);

  if (evenements.length === 0) return null;

  if (!ouvert) {
    return (
      <div style={{ marginBottom: '1.6rem' }}>
        {etat?.ok && <div className="msg ok">{etat.ok}</div>}
        <button type="button" className="btn btn-k btn-sm" onClick={() => setOuvert(true)}>
          + Ajouter un participant ou un exposant
        </button>
      </div>
    );
  }

  return (
    <div className="panel">
      <h2>{exposant ? 'Ajouter un exposant' : 'Ajouter un participant'}</h2>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap', marginBottom: '1.1rem' }}>
        <button type="button" className={`btn btn-sm ${exposant ? 'btn-w' : 'btn-k'}`}
          onClick={() => { setType('participant'); setEvenementId(''); vider(); }}>
          Participant
        </button>
        <button type="button" className={`btn btn-sm ${exposant ? 'btn-k' : 'btn-w'}`}
          onClick={() => { setType('exposant'); setEvenementId(''); vider(); }}>
          Exposant
        </button>
      </div>

      {!evt ? (
        <p style={{ color: '#6b6560', marginBottom: '1rem' }}>
          Aucun événement avec billetterie activée. Pour un exposant, choisis « Exposant ».
        </p>
      ) : (
        <form action={action}>
          <input type="hidden" name="type" value={type} />
          <div className="field">
            <label htmlFor="rm-evt">Événement</label>
            <select id="rm-evt" name="evenement_id" value={evt.id}
              onChange={(e) => { setEvenementId(e.target.value); vider(); }}>
              {choix.map((e) => <option key={e.id} value={e.id}>{e.titre}</option>)}
            </select>
          </div>

          <div className="row3">
            <div className="field">
              <label htmlFor="rm-nom">{exposant ? 'Nom ou structure' : 'Nom et prénom'}</label>
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
            <label>{exposant ? 'Formules' : 'Places'}</label>
            <table className="tbl" style={{ maxWidth: 560 }}>
              <tbody>
                {lignes.map((l) => (
                  <tr key={l.id}>
                    <td>{l.libelle}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>{l.id === 'defaut' && exposant ? 'prix libre' : euros(l.prix)}</td>
                    <td style={{ width: 110 }}>
                      <input type="hidden" name="tarif_id" value={l.id} />
                      <input
                        name="tarif_qte" type="number" min={0} max={99} inputMode="numeric"
                        aria-label={`Quantité ${l.libelle}`}
                        value={qtes[l.id] ?? 0}
                        onChange={(e) => setQtes((q) => ({ ...q, [l.id]: Math.max(0, Math.floor(Number(e.target.value) || 0)) }))}
                        style={{ ...champ, width: 90 }}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="row3">
            <div className="field">
              <label htmlFor="rm-montant">
                {exposant ? 'Montant' : `Montant (${quantite} place${quantite > 1 ? 's' : ''})`}
              </label>
              <input id="rm-montant" name="montant" inputMode="decimal"
                value={montantSaisi ?? enSaisie(total)} onChange={(e) => setMontantSaisi(e.target.value)} />
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
            <label htmlFor="rm-com">{exposant ? 'Activité, produits vendus, remarque' : 'Remarque (facultatif)'}</label>
            <input id="rm-com" name="commentaire" autoComplete="off" />
          </div>

          {!exposant && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '.5rem', marginBottom: '1.1rem', fontSize: '.9rem' }}>
              {paiement !== 'attente' && (
                <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
                  <input type="checkbox" name="envoyer_billet" defaultChecked style={{ width: 'auto' }} />
                  Envoyer le billet par e-mail (si une adresse est saisie)
                </label>
              )}
              {evt.places_max != null && (
                <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
                  <input type="checkbox" name="depasser" style={{ width: 'auto' }} />
                  Autoriser le dépassement de la jauge
                </label>
              )}
            </div>
          )}

          <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
            <button className="btn btn-k btn-sm" disabled={pending || quantite < 1}>
              {pending ? 'Enregistrement…' : exposant ? "Ajouter l'exposant" : 'Ajouter la réservation'}
            </button>
            <button type="button" className="btn btn-w btn-sm" onClick={() => setOuvert(false)}>Fermer</button>
          </div>
        </form>
      )}

      {exposant && evt && (
        <div style={{ marginTop: '1.6rem', paddingTop: '1.2rem', borderTop: '2px solid var(--noir)' }}>
          <h2 style={{ fontSize: '1rem' }}>Formules exposants de « {evt.titre} »</h2>
          {erreurFormule && <div className="msg ko">{erreurFormule}</div>}
          <table className="tbl" style={{ maxWidth: 560, marginBottom: '1rem' }}>
            <tbody>
              {formulesEvt.map((f) => (
                <tr key={f.id}>
                  <td>{f.libelle}</td>
                  <td style={{ whiteSpace: 'nowrap' }}>{euros(f.prix_centimes)}</td>
                  <td style={{ width: 110 }}>
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => start(async () => {
                        const r = await supprimerFormuleExposant(f.id);
                        setErreurFormule(r.erreur ?? '');
                      })}>
                      Retirer
                    </button>
                  </td>
                </tr>
              ))}
              {formulesEvt.length === 0 && (
                <tr><td colSpan={3} style={{ color: '#6b6560' }}>Aucune formule : l&apos;emplacement est à prix libre.</td></tr>
              )}
            </tbody>
          </table>
          <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
            <input aria-label="Libellé de la formule" placeholder="Ex. Emplacement 3 m, Table, Électricité"
              value={nouveauLibelle} onChange={(e) => setNouveauLibelle(e.target.value)}
              style={{ ...champ, flex: '2 1 220px', minWidth: 0 }} />
            <input aria-label="Prix de la formule" placeholder="Prix €" inputMode="decimal"
              value={nouveauPrix} onChange={(e) => setNouveauPrix(e.target.value)}
              style={{ ...champ, flex: '0 1 110px', minWidth: 0 }} />
            <button type="button" className="btn btn-y btn-sm" disabled={enCours}
              onClick={() => start(async () => {
                const r = await ajouterFormuleExposant(evt.id, nouveauLibelle, nouveauPrix);
                setErreurFormule(r.erreur ?? '');
                if (r.ok) { setNouveauLibelle(''); setNouveauPrix(''); }
              })}>
              Ajouter la formule
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
