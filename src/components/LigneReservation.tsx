'use client';
import { useEffect, useMemo, useState, useTransition } from 'react';
import {
  marquerScanne, changerStatutResa, supprimerReservation, verifierSumUpAdmin, encaisserReservation,
  modifierReservation, offrirRepas,
} from '@/app/reservation-actions';
import Confirmation from '@/components/Confirmation';

type Tarif = { id: string; evenement_id: string; libelle: string; prix_centimes: number };
type Ligne = { cle: string; libelle: string; prix_centimes: number; quantite: number };

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);
const enSaisie = (c: number) => (c / 100).toFixed(2).replace('.', ',');
const champ = { padding: '.45rem .6rem', border: '2px solid var(--noir)', fontFamily: 'inherit', fontSize: '.9rem', width: '100%' } as const;
const etiquette = { display: 'block', fontFamily: "'DM Mono', monospace", fontSize: '.62rem', textTransform: 'uppercase', letterSpacing: '.08em', marginBottom: '.25rem', color: '#6b6560' } as const;

const LIBELLES: Record<string, string> = {
  en_attente: 'En attente', payee: 'Payée', echouee: 'Échouée',
  expiree: 'Expirée', remboursee: 'Remboursée', annulee: 'Annulée',
};
const MODES: Record<string, string> = { especes: 'Espèces', cheque: 'Chèque' };
const MOTIFS_OFFERT = ['Bénévole', 'Gagnant d\u2019un jeu', 'Invité', 'Partenaire', 'Autre'];
/** Statuts depuis lesquels un paiement en espèces ou par chèque peut être enregistré. */
const ENCAISSABLES = ['en_attente', 'echouee', 'expiree'];

/**
 * Lignes modifiables : la grille de l'événement (tarifs ou formules exposants),
 * complétée par le détail déjà enregistré s'il ne correspond plus à la grille.
 */
function lignesInitiales(resa: any, grille: Tarif[]): Ligne[] {
  const existantes: any[] = resa.reservation_lignes ?? [];
  const lignes: Ligne[] = grille.map((t) => {
    const e = existantes.find((l) => l.libelle === t.libelle && l.prix_centimes === t.prix_centimes);
    return { cle: t.id, libelle: t.libelle, prix_centimes: t.prix_centimes, quantite: e?.quantite ?? 0 };
  });
  existantes.forEach((l, i) => {
    const deja = grille.some((t) => t.libelle === l.libelle && t.prix_centimes === t.prix_centimes);
    if (!deja) lignes.push({ cle: `ex-${i}`, libelle: l.libelle, prix_centimes: l.prix_centimes, quantite: l.quantite });
  });
  if (lignes.length === 0) {
    // Ni grille ni détail : une seule ligne, au prix moyen de la réservation.
    const prix = resa.places > 0 ? Math.round(resa.montant_centimes / resa.places) : resa.montant_centimes;
    lignes.push({ cle: 'defaut', libelle: resa.exposant ? 'Emplacement' : 'Place', prix_centimes: prix, quantite: resa.places });
  }
  return lignes;
}

export default function LigneReservation({
  resa, tarifs = [], formules = [],
}: { resa: any; tarifs?: Tarif[]; formules?: Tarif[] }) {
  const [pending, start] = useTransition();
  const [confirme, setConfirme] = useState(false);
  const [verif, setVerif] = useState('');
  const [statut, setStatut] = useState<string>(resa.statut);
  const [encaisse, setEncaisse] = useState(false);
  const [mode, setMode] = useState('especes');
  const [ref, setRef] = useState('');

  // Modification
  const [edition, setEdition] = useState(false);
  const [nom, setNom] = useState(resa.nom ?? '');
  const [email, setEmail] = useState(resa.email ?? '');
  const [telephone, setTelephone] = useState(resa.telephone ?? '');
  const [commentaire, setCommentaire] = useState(resa.commentaire ?? '');
  const [benevole, setBenevole] = useState<boolean>(!!resa.benevole);
  const [lignes, setLignes] = useState<Ligne[]>([]);
  const [montantSaisi, setMontantSaisi] = useState<string | null>(null);
  const [depasser, setDepasser] = useState(false);
  const [renvoyer, setRenvoyer] = useState(false);
  const [erreur, setErreur] = useState('');

  // Offrir le repas (bénévole, gagnant d'un jeu, invité…)
  const [offre, setOffre] = useState(false);
  const [motif, setMotif] = useState(MOTIFS_OFFERT[0]);
  const [motifLibre, setMotifLibre] = useState('');

  const grille = useMemo(
    () => (resa.exposant ? formules : tarifs).filter((t) => t.evenement_id === resa.evenement_id),
    [resa.exposant, resa.evenement_id, tarifs, formules],
  );

  // Le statut peut changer côté serveur (encaissement, vérification SumUp).
  useEffect(() => { setStatut(resa.statut); }, [resa.statut]);

  function ouvrirEdition() {
    setNom(resa.nom ?? ''); setEmail(resa.email ?? ''); setTelephone(resa.telephone ?? '');
    setCommentaire(resa.commentaire ?? ''); setBenevole(!!resa.benevole);
    setLignes(lignesInitiales(resa, grille));
    // Montant enregistré différent du tarif : on le garde tel quel.
    const tarif = lignesInitiales(resa, grille).reduce((s, l) => s + l.prix_centimes * l.quantite, 0);
    setMontantSaisi(tarif === resa.montant_centimes ? null : enSaisie(resa.montant_centimes));
    setDepasser(false); setRenvoyer(false); setErreur('');
    setEncaisse(false); setOffre(false);
    setEdition(true);
  }

  const totalTarif = lignes.reduce((s, l) => s + l.prix_centimes * l.quantite, 0);
  const quantite = lignes.reduce((s, l) => s + l.quantite, 0);
  const montantAffiche = benevole ? '0,00' : (montantSaisi ?? enSaisie(totalTarif));

  function enregistrer() {
    const fd = new FormData();
    fd.set('nom', nom); fd.set('email', email); fd.set('telephone', telephone); fd.set('commentaire', commentaire);
    fd.set('montant', benevole ? '0' : (montantSaisi ?? enSaisie(totalTarif)));
    fd.set('lignes', JSON.stringify(lignes.filter((l) => l.quantite > 0).map(({ libelle, prix_centimes, quantite }) => ({ libelle, prix_centimes, quantite }))));
    if (benevole) fd.set('benevole', 'on');
    if (depasser) fd.set('depasser', 'on');
    if (renvoyer) fd.set('renvoyer_billet', 'on');
    setErreur('');
    start(async () => {
      const r = await modifierReservation(resa.id, fd);
      if (r.erreur) setErreur(r.erreur);
      else { setEdition(false); setVerif(r.ok ?? 'Modifiée'); }
    });
  }

  const colonnes = 7;

  return (
    <>
      <tr style={{ opacity: pending ? .5 : 1 }}>
        <td data-l="Acheteur" className="bloc">
          <strong>{resa.nom}</strong>
          {resa.exposant && <> <span className="pill done">Exposant</span></>}
          {resa.benevole && <> <span className="pill new">Offert</span></>}
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
          {resa.benevole ? <span style={{ color: '#6b6560' }}>offert</span> : euros(resa.montant_centimes)}
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
          <button className="btn btn-y btn-sm" style={{ marginRight: '.4rem' }}
            onClick={() => (edition ? setEdition(false) : ouvrirEdition())}>
            {edition ? 'Fermer' : 'Modifier'}
          </button>
          {ENCAISSABLES.includes(resa.statut) && !resa.benevole && (
            <button className="btn btn-k btn-sm" style={{ marginRight: '.4rem' }}
              onClick={() => { setEdition(false); setOffre(false); setEncaisse((v) => !v); }}>
              Encaisser
            </button>
          )}
          {!resa.exposant && !resa.benevole && ['payee', ...ENCAISSABLES].includes(resa.statut) && (
            <button className="btn btn-w btn-sm" title="Repas offert : bénévole, gagnant d'un jeu, invité" style={{ marginRight: '.4rem' }}
              onClick={() => { setEdition(false); setEncaisse(false); setOffre((v) => !v); }}>
              Offrir
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

      {edition && (
        <tr>
          <td colSpan={colonnes} style={{ background: '#FBF4E4', padding: '1rem .8rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: '.6rem', flexWrap: 'wrap', alignItems: 'baseline', marginBottom: '.8rem' }}>
              <strong style={{ fontSize: '.95rem' }}>Modifier la réservation {resa.reference}</strong>
              <span style={{ fontSize: '.78rem', color: '#6b6560' }}>{resa.evenements?.titre}</span>
            </div>
            {erreur && <div className="msg ko">{erreur}</div>}

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '.8rem', marginBottom: '.9rem' }}>
              <label style={{ display: 'block' }}>
                <span style={etiquette}>{resa.exposant ? 'Nom ou structure' : 'Nom et prénom'}</span>
                <input value={nom} onChange={(e) => setNom(e.target.value)} style={champ} />
              </label>
              <label style={{ display: 'block' }}>
                <span style={etiquette}>Téléphone</span>
                <input type="tel" value={telephone} onChange={(e) => setTelephone(e.target.value)} style={champ} />
              </label>
              <label style={{ display: 'block' }}>
                <span style={etiquette}>E-mail</span>
                <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} style={champ} />
              </label>
            </div>

            <span style={etiquette}>{resa.exposant ? 'Formules' : benevole ? 'Repas (par menu)' : 'Places'}</span>
            <div style={{ maxWidth: 560, marginBottom: '.9rem' }}>
              {lignes.map((l) => (
                <div key={l.cle} style={{ display: 'flex', alignItems: 'center', gap: '.8rem', padding: '.35rem 0', borderBottom: '1px solid #e2ddd6', fontSize: '.9rem' }}>
                  <span style={{ flex: 1 }}>{l.libelle}</span>
                  <span style={{ whiteSpace: 'nowrap', color: '#6b6560' }}>
                    {benevole ? <>offert <s style={{ color: '#8a7f6f' }}>{euros(l.prix_centimes)}</s></> : euros(l.prix_centimes)}
                  </span>
                  <input
                    type="number" min={0} max={99} inputMode="numeric" aria-label={`Quantité ${l.libelle}`}
                    value={l.quantite}
                    onChange={(e) => {
                      const q = Math.max(0, Math.floor(Number(e.target.value) || 0));
                      setLignes((ls) => ls.map((x) => (x.cle === l.cle ? { ...x, quantite: q } : x)));
                    }}
                    style={{ ...champ, width: 80, flex: '0 0 80px' }}
                  />
                </div>
              ))}
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '.8rem', marginBottom: '.9rem' }}>
              <label style={{ display: 'block' }}>
                <span style={etiquette}>
                  {resa.exposant ? 'Montant' : `Montant (${quantite} ${benevole ? 'repas' : `place${quantite > 1 ? 's' : ''}`})`}
                </span>
                <input inputMode="decimal" value={montantAffiche} disabled={benevole}
                  onChange={(e) => setMontantSaisi(e.target.value)} style={champ} />
                {!benevole && montantSaisi !== null && (
                  <span style={{ fontSize: '.75rem', color: '#6b6560' }}>
                    Tarif normal {euros(totalTarif)}.{' '}
                    <button type="button" onClick={() => setMontantSaisi(null)}
                      style={{ background: 'none', border: 'none', textDecoration: 'underline', cursor: 'pointer', fontFamily: 'inherit', fontSize: 'inherit', padding: 0 }}>
                      Revenir au tarif
                    </button>
                  </span>
                )}
              </label>
              <label style={{ display: 'block' }}>
                <span style={etiquette}>{resa.exposant ? 'Activité, remarque' : 'Remarque'}</span>
                <input value={commentaire} onChange={(e) => setCommentaire(e.target.value)} style={champ} />
              </label>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '.45rem', marginBottom: '1rem', fontSize: '.88rem' }}>
              {!resa.exposant && (
                <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
                  <input type="checkbox" checked={benevole} onChange={(e) => setBenevole(e.target.checked)} style={{ width: 'auto' }} />
                  Repas offert (bénévole, gagnant d\u2019un jeu, invité) : 0 € à encaisser, compté pour le traiteur
                </label>
              )}
              {!resa.exposant && quantite > resa.places && (
                <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
                  <input type="checkbox" checked={depasser} onChange={(e) => setDepasser(e.target.checked)} style={{ width: 'auto' }} />
                  Autoriser le dépassement de la jauge
                </label>
              )}
              {!resa.exposant && resa.statut === 'payee' && email && (
                <label style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}>
                  <input type="checkbox" checked={renvoyer} onChange={(e) => setRenvoyer(e.target.checked)} style={{ width: 'auto' }} />
                  Renvoyer le billet mis à jour par e-mail
                </label>
              )}
              {resa.checkout_id && resa.statut === 'payee' && !benevole && (
                <span style={{ fontSize: '.78rem', color: '#8a7f6f' }}>
                  Paiement SumUp déjà encaissé : modifier le montant ne rembourse ni ne prélève rien, le remboursement se fait depuis SumUp.
                </span>
              )}
            </div>

            <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
              <button className="btn btn-k btn-sm" disabled={pending || quantite < 1 || nom.trim().length < 2} onClick={enregistrer}>
                {pending ? 'Enregistrement…' : 'Enregistrer les modifications'}
              </button>
              <button className="btn btn-w btn-sm" onClick={() => setEdition(false)}>Annuler</button>
            </div>
          </td>
        </tr>
      )}

      {offre && (
        <tr>
          <td colSpan={colonnes} style={{ background: '#FFF6D6' }}>
            <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', alignItems: 'center' }}>
              <strong style={{ fontSize: '.9rem' }}>
                Offrir {resa.places > 1 ? `les ${resa.places} repas` : 'le repas'} de {resa.nom}
              </strong>
              <select
                aria-label="Motif" value={motif} onChange={(e) => setMotif(e.target.value)}
                style={{ padding: '.45rem', border: '2px solid var(--noir)', fontFamily: 'inherit' }}
              >
                {MOTIFS_OFFERT.map((m) => <option key={m} value={m}>{m}</option>)}
              </select>
              {motif === 'Autre' && (
                <input
                  aria-label="Précision" placeholder="Précision (ex. lot de la tombola)" value={motifLibre}
                  onChange={(e) => setMotifLibre(e.target.value)}
                  style={{ padding: '.45rem .6rem', border: '2px solid var(--noir)', fontFamily: 'inherit', minWidth: 200 }}
                />
              )}
              <button
                className="btn btn-k btn-sm" disabled={pending}
                onClick={() => start(async () => {
                  const r = await offrirRepas(resa.id, motif === 'Autre' ? motifLibre : motif);
                  if (r.erreur) setVerif(r.erreur);
                  else { setOffre(false); setVerif(r.ok ?? 'Repas offert'); }
                })}
              >
                Confirmer
              </button>
              <button className="btn btn-w btn-sm" onClick={() => setOffre(false)}>Annuler</button>
            </div>
            <div style={{ fontSize: '.78rem', color: '#6b6560', marginTop: '.5rem' }}>
              Passe à 0 €, reste compté dans la jauge, au pointage et dans la liste traiteur.
              {resa.statut === 'payee' && resa.montant_centimes > 0 && (
                <> <strong>{euros(resa.montant_centimes)} déjà encaissés</strong> : à rembourser {resa.checkout_id ? 'depuis SumUp' : 'en main propre'}.</>
              )}
              {' '}Pour annuler ensuite : « Modifier », décocher « Repas offert ».
            </div>
          </td>
        </tr>
      )}

      {encaisse && ENCAISSABLES.includes(resa.statut) && (
        <tr>
          <td colSpan={colonnes} style={{ background: '#FFF6D6' }}>
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
        detail={resa.benevole
          ? 'Repas offert : rien à rembourser. Pour corriger le nombre de repas, utilise plutôt « Modifier ».'
          : resa.mode_paiement
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
