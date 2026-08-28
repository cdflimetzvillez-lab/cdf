'use client';
import { useActionState, useMemo, useState } from 'react';
import { reserver, type EtatResa } from '@/app/reservation-actions';

export type TarifPublic = {
  id: string;
  libelle: string;
  description: string | null;
  prix_centimes: number;
};

type Props = {
  evenementId: string;
  tarifs: TarifPublic[];
  prixCentimes: number;        // repli si aucun tarif défini
  placesMax: number;
  placesRestantes: number | null;
  cloture: string | null;
};

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);

export default function FormulaireReservation({
  evenementId, tarifs, prixCentimes, placesMax, placesRestantes, cloture,
}: Props) {
  const [etat, action, pending] = useActionState<EtatResa, FormData>(reserver, null);

  // Si aucun tarif n'est saisi, on retombe sur le prix unique de l'événement.
  const grille: TarifPublic[] = tarifs.length
    ? tarifs
    : [{ id: 'defaut', libelle: 'Place', description: null, prix_centimes: prixCentimes }];

  const [quantites, setQuantites] = useState<Record<string, number>>(
    Object.fromEntries(grille.map((t, i) => [t.id, i === 0 ? 1 : 0]))
  );

  const complet = placesRestantes !== null && placesRestantes <= 0;
  const close = cloture ? new Date(cloture) < new Date() : false;
  const plafond = Math.min(placesMax, placesRestantes ?? placesMax);

  const { total, nbPlaces } = useMemo(() => {
    let total = 0, nbPlaces = 0;
    grille.forEach((t) => {
      const q = quantites[t.id] ?? 0;
      total += t.prix_centimes * q;
      nbPlaces += q;
    });
    return { total, nbPlaces };
  }, [quantites, grille]);

  function changer(id: string, delta: number) {
    setQuantites((q) => {
      const actuel = q[id] ?? 0;
      const nouveau = Math.max(0, actuel + delta);
      const autres = nbPlaces - actuel;
      if (autres + nouveau > plafond) return q;
      return { ...q, [id]: nouveau };
    });
  }

  if (complet) {
    return (
      <div className="form-box">
        <h3>Complet</h3>
        <p style={{ fontWeight: 600 }}>
          Toutes les places ont trouvé preneur. Écrivez-nous pour être
          prévenu en cas de désistement.
        </p>
      </div>
    );
  }

  if (close) {
    return (
      <div className="form-box">
        <h3>Réservations closes</h3>
        <p style={{ fontWeight: 600 }}>
          La date limite de réservation est passée. Contactez le comité
          pour savoir s&apos;il reste des possibilités.
        </p>
      </div>
    );
  }

  return (
    <form className="form-box" action={action}>
      <h3>Réserver</h3>
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <input type="hidden" name="evenement_id" value={evenementId} />

      {/* --- grille tarifaire --- */}
      <div className="tarif-grille">
        {grille.map((t) => (
          <div className="tarif-ligne" key={t.id}>
            <input type="hidden" name="tarif_id" value={t.id} />
            <input type="hidden" name="tarif_qte" value={quantites[t.id] ?? 0} />

            <div className="tarif-nom">
              <strong>{t.libelle}</strong>
              {t.description && <span>{t.description}</span>}
              <em>{t.prix_centimes === 0 ? 'Gratuit' : euros(t.prix_centimes)}</em>
            </div>

            <div className="tarif-compteur">
              <button type="button" onClick={() => changer(t.id, -1)}
                disabled={(quantites[t.id] ?? 0) === 0} aria-label={`Retirer une place ${t.libelle}`}>−</button>
              <span>{quantites[t.id] ?? 0}</span>
              <button type="button" onClick={() => changer(t.id, 1)}
                disabled={nbPlaces >= plafond} aria-label={`Ajouter une place ${t.libelle}`}>+</button>
            </div>
          </div>
        ))}
      </div>

      <div className="field">
        <label htmlFor="r-nom">Nom et prénom</label>
        <input id="r-nom" name="nom" required placeholder="Marie Dupont" />
      </div>

      <div className="field">
        <label htmlFor="r-email">Email</label>
        <input id="r-email" name="email" type="email" required placeholder="vous@exemple.fr" />
        <small style={{ fontSize: '.72rem', color: '#6b6560' }}>
          Votre billet y sera envoyé.
        </small>
      </div>

      <div className="field">
        <label htmlFor="r-tel">Téléphone</label>
        <input id="r-tel" name="telephone" type="tel" required placeholder="06 12 34 56 78" />
        <small style={{ fontSize: '.72rem', color: '#6b6560' }}>
          Pour vous joindre en cas de changement de dernière minute.
        </small>
      </div>

      <div className="field">
        <label htmlFor="r-comm">Remarque (allergies, table commune…)</label>
        <textarea id="r-comm" name="commentaire" rows={2} />
      </div>

      <div className="resa-total">
        <span>Total · {nbPlaces} place{nbPlaces > 1 ? 's' : ''}</span>
        <b>{euros(total)}</b>
      </div>

      {placesRestantes !== null && placesRestantes <= 20 && (
        <p className="resa-alerte">
          Plus que {placesRestantes} place{placesRestantes > 1 ? 's' : ''} disponible
          {placesRestantes > 1 ? 's' : ''}.
        </p>
      )}

      <button className="btn btn-k" style={{ width: '100%' }}
        disabled={pending || nbPlaces === 0}>
        {pending ? 'Redirection…'
          : nbPlaces === 0 ? 'Choisissez au moins une place'
          : `Payer ${euros(total)}`}
      </button>

      <p style={{ fontSize: '.72rem', color: '#6b6560', marginTop: '.9rem', lineHeight: 1.5 }}>
        Paiement sécurisé par SumUp. Vous serez redirigé vers leur page,
        aucune donnée bancaire ne transite par ce site.
      </p>
    </form>
  );
}
