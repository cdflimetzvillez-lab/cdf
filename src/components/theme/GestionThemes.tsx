'use client';
import { useActionState, useEffect, useState, useTransition } from 'react';
import { basculerTheme, enregistrerTheme, supprimerTheme, type EtatThemeForm } from '@/app/theme-actions';
import {
  COULEUR_VALIDE, MODELES, MOTIFS, dateTheme, etatTheme, variablesTheme,
  type MotifTheme, type ThemeAccueil,
} from '@/lib/theme/types';
import { BlocTheme, Neige, PastilleTheme } from '@/components/theme/ThemeAccueil';

const ETATS = {
  en_ligne: { libelle: 'En ligne', classe: 'on' },
  programme: { libelle: 'Programmé', classe: 'new' },
  passe: { libelle: 'Passé', classe: 'off' },
  desactive: { libelle: 'Désactivé', classe: 'off' },
} as const;

const vide = (annee: number): ThemeAccueil => ({
  id: '', nom: '', couleur: '#F591BC', motif: 'aucun', etiquette: '', bandeau: '',
  titre: '', texte: '', bouton: 'En savoir plus', lien: '',
  debut: `${annee}-01-01`, fin: `${annee}-01-31`, actif: true,
});

/** Liste des thèmes programmés, formulaire d'ajout ou de modification, et aperçu. */
export default function GestionThemes({ themes, annee }: { themes: ThemeAccueil[]; annee: number }) {
  const [t, setT] = useState<ThemeAccueil>(vide(annee));
  const [modele, setModele] = useState('');
  const [message, setMessage] = useState('');
  const [etat, action, pending] = useActionState<EtatThemeForm, FormData>(enregistrerTheme, null);
  const [enCours, start] = useTransition();
  const maj = <K extends keyof ThemeAccueil>(cle: K, valeur: ThemeAccueil[K]) => setT((x) => ({ ...x, [cle]: valeur }));

  // Après un enregistrement réussi : retour à un formulaire vide.
  useEffect(() => {
    if (etat?.ok) { setT(vide(annee)); setModele(''); }
  }, [etat, annee]);

  function choisirModele(cle: string) {
    setModele(cle);
    const m = MODELES[cle];
    if (!m) return;
    const { du, au, ...reste } = m;
    setT((x) => ({ ...x, ...reste, debut: `${annee}-${du}`, fin: `${annee}-${au}` }));
  }

  const couleurOk = COULEUR_VALIDE.test(t.couleur);
  const apercu = couleurOk ? t : { ...t, couleur: '#F591BC' };
  const style = variablesTheme(apercu) as React.CSSProperties;

  return (
    <>
      <div className="panel">
        <h2>Thèmes programmés</h2>
        {message && <div className="msg ko">{message}</div>}
        <table className="tbl cartes compact">
          <thead><tr><th>Thème</th><th>Couleur</th><th>Période</th><th>État</th><th></th></tr></thead>
          <tbody>
            {themes.map((x) => {
              const e = ETATS[etatTheme(x)];
              return (
                <tr key={x.id} style={{ opacity: enCours ? .6 : 1 }}>
                  <td data-l="Thème" className="bloc"><strong>{x.nom}</strong></td>
                  <td data-l="Couleur"><i className="th-pt" style={{ background: x.couleur }} /></td>
                  <td data-l="Période">du {dateTheme(x.debut)} au {dateTheme(x.fin)}</td>
                  <td data-l="État"><span className={`pill ${e.classe}`}>{e.libelle}</span></td>
                  <td className="actions">
                    <button type="button" className="btn btn-y btn-sm" onClick={() => { setT(x); setModele(''); }}>Modifier</button>{' '}
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => start(async () => { const r = await basculerTheme(x.id, !x.actif); setMessage(r?.erreur ?? ''); })}>
                      {x.actif ? 'Désactiver' : 'Activer'}
                    </button>{' '}
                    <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                      onClick={() => {
                        if (!window.confirm(`Supprimer le thème « ${x.nom} » ?`)) return;
                        start(async () => { const r = await supprimerTheme(x.id); setMessage(r?.erreur ?? ''); });
                      }}>
                      Suppr.
                    </button>
                  </td>
                </tr>
              );
            })}
            {themes.length === 0 && (
              <tr><td colSpan={5} style={{ color: '#6b6560' }}>Aucun thème. Choisis un modèle ci-dessous pour commencer.</td></tr>
            )}
          </tbody>
        </table>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.9rem' }}>
          Un thème s&apos;affiche du premier au dernier jour inclus, puis se retire tout seul. Si deux thèmes se chevauchent,
          le plus récemment commencé s&apos;affiche.
        </p>
      </div>

      <form action={action} className="panel">
        <h2>{t.id ? `Modifier « ${t.nom} »` : 'Ajouter un thème'}</h2>
        {etat?.ok && <div className="msg ok">{etat.ok}</div>}
        {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}
        <input type="hidden" name="id" value={t.id} />

        {!t.id && (
          <div className="field">
            <label htmlFor="th-modele">Partir d&apos;un modèle</label>
            <select id="th-modele" value={modele} onChange={(e) => choisirModele(e.target.value)}>
              <option value="">Thème personnalisé</option>
              {Object.entries(MODELES).map(([cle, m]) => <option key={cle} value={cle}>{m.nom}</option>)}
            </select>
          </div>
        )}

        <div className="row3">
          <div className="field">
            <label htmlFor="th-nom">Nom du thème</label>
            <input id="th-nom" name="nom" value={t.nom} maxLength={40} required onChange={(e) => maj('nom', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-debut">Du</label>
            <input id="th-debut" name="debut" type="date" value={t.debut} required onChange={(e) => maj('debut', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-fin">Au (inclus)</label>
            <input id="th-fin" name="fin" type="date" value={t.fin} required onChange={(e) => maj('fin', e.target.value)} />
          </div>
        </div>

        <div className="row3">
          <div className="field">
            <label htmlFor="th-couleur">Couleur du haut de page</label>
            <div style={{ display: 'flex', gap: '.5rem' }}>
              <input type="color" aria-label="Choisir la couleur" value={couleurOk ? t.couleur : '#F591BC'}
                onChange={(e) => maj('couleur', e.target.value.toUpperCase())}
                style={{ width: 56, padding: 2, flex: 'none' }} />
              <input id="th-couleur" name="couleur" value={t.couleur} maxLength={7} required
                onChange={(e) => maj('couleur', e.target.value)} />
            </div>
          </div>
          <div className="field">
            <label htmlFor="th-motif">Motif</label>
            <select id="th-motif" name="motif" value={t.motif} onChange={(e) => maj('motif', e.target.value as MotifTheme)}>
              {Object.entries(MOTIFS).map(([cle, libelle]) => <option key={cle} value={cle}>{libelle}</option>)}
            </select>
          </div>
          <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center', marginTop: '1.4rem' }}>
            <input type="checkbox" name="actif" checked={t.actif} onChange={(e) => maj('actif', e.target.checked)} style={{ width: 'auto' }} />
            Thème activé
          </label>
        </div>

        <div className="row2">
          <div className="field">
            <label htmlFor="th-etiquette">Étiquette au-dessus du titre</label>
            <input id="th-etiquette" name="etiquette" value={t.etiquette} maxLength={60}
              placeholder="Octobre Rose · Limetz-Villez" onChange={(e) => maj('etiquette', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-bandeau">Message du bandeau défilant</label>
            <input id="th-bandeau" name="bandeau" value={t.bandeau} maxLength={80} onChange={(e) => maj('bandeau', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label htmlFor="th-titre">Titre du bloc de message (facultatif)</label>
          <input id="th-titre" name="titre" value={t.titre} maxLength={90} onChange={(e) => maj('titre', e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="th-texte">Texte du bloc de message (facultatif)</label>
          <textarea id="th-texte" name="texte" rows={3} value={t.texte} maxLength={400} onChange={(e) => maj('texte', e.target.value)} />
        </div>
        <div className="row2">
          <div className="field">
            <label htmlFor="th-bouton">Texte du bouton</label>
            <input id="th-bouton" name="bouton" value={t.bouton} maxLength={30} onChange={(e) => maj('bouton', e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="th-lien">Lien du bouton (vide = pas de bouton)</label>
            <input id="th-lien" name="lien" value={t.lien} maxLength={300} placeholder="https://… ou /evenements/…"
              onChange={(e) => maj('lien', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label>Aperçu</label>
          <div className="th-apercu" style={style}>
            <div className="th-apercu-hero">
              <Neige theme={apercu} />
              <PastilleTheme theme={{ ...apercu, nom: apercu.nom || 'Nom du thème' }} />
              <div><span className="kicker mono">{apercu.etiquette || 'Saison · Limetz-Villez'}</span></div>
              <h3>Toute <span className="a1">l&apos;année</span><br /><span className="a2">on fait la fête</span></h3>
            </div>
            <div className="th-bandeau">
              <div className="marquee"><div><span>{apercu.bandeau || 'Message du bandeau'}</span><span>Prochains événements</span></div></div>
            </div>
            <BlocTheme theme={apercu} />
          </div>
        </div>

        <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
          <button className="btn btn-k btn-sm" disabled={pending}>
            {pending ? 'Enregistrement…' : t.id ? 'Enregistrer les modifications' : 'Ajouter le thème'}
          </button>
          {t.id && (
            <button type="button" className="btn btn-w btn-sm" onClick={() => { setT(vide(annee)); setModele(''); }}>
              Annuler la modification
            </button>
          )}
        </div>
      </form>
    </>
  );
}
