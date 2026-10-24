'use client';
import { useMemo, useState, useTransition, useOptimistic } from 'react';
import { majArrivees } from '@/app/pointage-actions';

type Resa = {
  id: string;
  nom: string;
  email: string;
  telephone: string | null;
  commentaire: string | null;
  places: number;
  places_arrivees: number;
  code_billet: string;
  reference: string;
  benevole?: boolean;
  exposant?: boolean;
};

type Filtre = 'tous' | 'attendus' | 'arrives';

const sansAccent = (s: string) =>
  s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

export default function PointageListe({ reservations }: { reservations: Resa[] }) {
  const [recherche, setRecherche] = useState('');
  const [filtre, setFiltre] = useState<Filtre>('tous');
  const [, start] = useTransition();

  const [liste, setOptimiste] = useOptimistic(
    reservations,
    (etat: Resa[], maj: { id: string; arrivees: number }) =>
      etat.map((r) => (r.id === maj.id ? { ...r, places_arrivees: maj.arrivees } : r))
  );

  const totaux = useMemo(() => {
    const attendus = liste.reduce((s, r) => s + r.places, 0);
    const arrives = liste.reduce((s, r) => s + r.places_arrivees, 0);
    return { attendus, arrives, reste: attendus - arrives };
  }, [liste]);

  const affichees = useMemo(() => {
    const q = sansAccent(recherche.trim());
    return liste
      .filter((r) => {
        if (filtre === 'arrives' && r.places_arrivees === 0) return false;
        if (filtre === 'attendus' && r.places_arrivees >= r.places) return false;
        if (!q) return true;
        return (
          sansAccent(r.nom).includes(q) ||
          r.code_billet.toLowerCase().includes(q) ||
          (r.telephone ?? '').replace(/\s/g, '').includes(q.replace(/\s/g, ''))
        );
      })
      .sort((a, b) => a.nom.localeCompare(b.nom, 'fr'));
  }, [liste, recherche, filtre]);

  function changer(r: Resa, arrivees: number) {
    const v = Math.max(0, Math.min(arrivees, r.places));
    start(async () => {
      setOptimiste({ id: r.id, arrivees: v });
      await majArrivees(r.id, v);
    });
  }

  return (
    <div className="ptg">
      <div className="ptg-compteurs">
        <div className="ptg-kpi ok">
          <b>{totaux.arrives}</b><span>Arrivés</span>
        </div>
        <div className="ptg-kpi">
          <b>{totaux.reste}</b><span>Attendus</span>
        </div>
        <div className="ptg-kpi">
          <b>{totaux.attendus}</b><span>Total</span>
        </div>
      </div>

      <div className="ptg-barre">
        <div className="ptg-jauge">
          <span style={{
            width: totaux.attendus
              ? `${(totaux.arrives / totaux.attendus) * 100}%` : '0%',
          }} />
        </div>
      </div>

      <input
        className="ptg-recherche"
        type="search"
        inputMode="search"
        placeholder="Nom, code billet ou téléphone…"
        value={recherche}
        onChange={(e) => setRecherche(e.target.value)}
      />

      <div className="ptg-filtres">
        {([
          ['tous', 'Tous'],
          ['attendus', 'À venir'],
          ['arrives', 'Arrivés'],
        ] as [Filtre, string][]).map(([v, l]) => (
          <button
            key={v}
            className={`ptg-filtre${filtre === v ? ' on' : ''}`}
            onClick={() => setFiltre(v)}
          >
            {l}
          </button>
        ))}
      </div>

      <div className="ptg-liste">
        {affichees.map((r) => {
          const complet = r.places_arrivees >= r.places;
          const partiel = r.places_arrivees > 0 && !complet;

          return (
            <div
              key={r.id}
              className={`ptg-carte${complet ? ' complet' : ''}${partiel ? ' partiel' : ''}`}
            >
              <div className="ptg-tete">
                <div>
                  <div className="ptg-nom">
                    {r.nom}
                    {r.benevole && <span style={{ fontSize: '.6rem', fontFamily: "'DM Mono', monospace", textTransform: 'uppercase', letterSpacing: '.08em', marginLeft: '.5rem', padding: '.15rem .45rem', background: 'var(--jaune)', color: 'var(--noir)', verticalAlign: 'middle' }}>Bénévole</span>}
                    {r.exposant && <span style={{ fontSize: '.6rem', fontFamily: "'DM Mono', monospace", textTransform: 'uppercase', letterSpacing: '.08em', marginLeft: '.5rem', padding: '.15rem .45rem', background: '#9BD44F', color: 'var(--noir)', verticalAlign: 'middle' }}>Exposant</span>}
                  </div>
                  <div className="ptg-meta">
                    <code>{r.code_billet}</code>
                    {r.telephone && (
                      <> · <a href={`tel:${r.telephone.replace(/\s/g, '')}`}>{r.telephone}</a></>
                    )}
                  </div>
                </div>
                <div className="ptg-ratio">
                  {r.places_arrivees}<span>/{r.places}</span>
                </div>
              </div>

              {r.commentaire && <div className="ptg-note">{r.commentaire}</div>}

              {r.places === 1 ? (
                <button
                  className={`ptg-bouton${complet ? ' annule' : ''}`}
                  onClick={() => changer(r, complet ? 0 : 1)}
                >
                  {complet ? 'Annuler l\u2019arrivée' : 'Marquer arrivé'}
                </button>
              ) : (
                <div className="ptg-compteur">
                  <button
                    onClick={() => changer(r, r.places_arrivees - 1)}
                    disabled={r.places_arrivees === 0}
                    aria-label="Retirer une personne"
                  >−</button>

                  <div className="ptg-pastilles">
                    {Array.from({ length: r.places }, (_, i) => (
                      <button
                        key={i}
                        className={`ptg-pastille${i < r.places_arrivees ? ' on' : ''}`}
                        onClick={() => changer(r, i + 1 === r.places_arrivees ? i : i + 1)}
                        aria-label={`${i + 1} personne${i > 0 ? 's' : ''} arrivée${i > 0 ? 's' : ''}`}
                      >
                        {i + 1}
                      </button>
                    ))}
                  </div>

                  <button
                    onClick={() => changer(r, r.places_arrivees + 1)}
                    disabled={complet}
                    aria-label="Ajouter une personne"
                  >+</button>
                </div>
              )}
            </div>
          );
        })}

        {affichees.length === 0 && (
          <p className="ptg-vide">
            {recherche ? 'Aucun résultat pour cette recherche.' : 'Aucune réservation.'}
          </p>
        )}
      </div>
    </div>
  );
}
