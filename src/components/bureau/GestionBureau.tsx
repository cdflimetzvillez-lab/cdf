'use client';
import { Fragment, useActionState, useState, useTransition } from 'react';
import {
  ajouterPoste, basculerAcces, basculerMembre, changerPoste, creerMembre,
  nouveauMotDePasse, supprimerMembre, supprimerPoste, type EtatBureau,
} from '@/app/bureau-actions';
import { CATEGORIES, MODULES_ATTRIBUABLES } from '@/lib/bureau/modules';

export type MembreBureau = {
  id: string; email: string; nom: string | null; role: string | null; poste: string | null; actif: boolean | null;
};
export type PosteBureau = { cle: string; libelle: string; modules: string[]; position: number };

const select = { padding: '.4rem', border: '2px solid var(--noir)', fontFamily: 'inherit', background: '#fff' } as const;

export default function GestionBureau({ membres, postes, moi }: { membres: MembreBureau[]; postes: PosteBureau[]; moi: string }) {
  const [retour, setRetour] = useState<EtatBureau>(null);
  const [enCours, start] = useTransition();
  const [etatMembre, actionMembre, envoiMembre] = useActionState<EtatBureau, FormData>(creerMembre, null);
  const [etatPoste, actionPoste, envoiPoste] = useActionState<EtatBureau, FormData>(ajouterPoste, null);

  const lancer = (action: () => Promise<EtatBureau>) => start(async () => setRetour(await action()));
  // Cases de la grille : cochées tout de suite à l'écran, sans attendre la réponse du serveur.
  const [local, setLocal] = useState<Record<string, boolean>>({});
  function basculer(poste: string, module: string, accorde: boolean) {
    const cle = `${poste}:${module}`;
    setLocal((v) => ({ ...v, [cle]: accorde }));
    start(async () => {
      const r = await basculerAcces(poste, module, accorde);
      setRetour(r);
      if (r?.erreur) setLocal((v) => { const { [cle]: _retire, ...reste } = v; return reste; });
    });
  }
  // Un ancien compte sans rôle est un administrateur.
  const valeurPoste = (m: MembreBureau) => ((m.role ?? 'admin') === 'admin' ? 'admin' : m.poste ?? '');
  const utilise = (cle: string) => membres.some((m) => m.poste === cle);
  const provisoire = etatMembre?.motDePasse ? etatMembre : retour?.motDePasse ? retour : null;

  return (
    <>
      {provisoire?.motDePasse && (
        <div className="msg ok">
          {provisoire.ok} Mot de passe provisoire :{' '}
          <code style={{ fontSize: '1.05rem', background: '#fff', padding: '.15rem .45rem', border: '2px solid var(--noir)', userSelect: 'all' }}>
            {provisoire.motDePasse}
          </code>
          <br />
          <span style={{ fontWeight: 400, fontSize: '.85rem' }}>
            Note-le maintenant et transmets-le au membre : il ne sera plus affiché. Connexion sur /admin/login.
          </span>
        </div>
      )}
      {retour?.erreur && <div className="msg ko">{retour.erreur}</div>}

      <div className="panel">
        <h2>Membres ({membres.length})</h2>
        <table className="tbl cartes compact">
          <thead><tr><th>Nom</th><th>E-mail</th><th>Poste</th><th>État</th><th></th></tr></thead>
          <tbody>
            {membres.map((m) => {
              const actif = m.actif !== false;
              return (
                <tr key={m.id} style={{ opacity: enCours ? .6 : 1 }}>
                  <td data-l="Nom" className="bloc"><strong>{m.nom || 'Sans nom'}</strong>{m.id === moi && ' (toi)'}</td>
                  <td data-l="E-mail" style={{ fontSize: '.85rem' }}>{m.email}</td>
                  <td data-l="Poste">
                    <select aria-label={`Poste de ${m.nom ?? m.email}`} value={valeurPoste(m)} style={select}
                      onChange={(e) => lancer(() => changerPoste(m.id, e.target.value))}>
                      {valeurPoste(m) === '' && <option value="">À attribuer</option>}
                      <option value="admin">Administrateur (tout)</option>
                      {postes.map((p) => <option key={p.cle} value={p.cle}>{p.libelle}</option>)}
                    </select>
                  </td>
                  <td data-l="État"><span className={`pill ${actif ? 'on' : 'off'}`}>{actif ? 'Actif' : 'Désactivé'}</span></td>
                  <td className="actions">
                    <button type="button" className="btn btn-y btn-sm" disabled={enCours}
                      onClick={() => {
                        if (window.confirm(`Générer un nouveau mot de passe pour ${m.nom ?? m.email} ? L'ancien ne fonctionnera plus.`)) {
                          lancer(() => nouveauMotDePasse(m.id));
                        }
                      }}>
                      Mot de passe
                    </button>{' '}
                    {m.id !== moi && (
                      <>
                        <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                          onClick={() => lancer(() => basculerMembre(m.id, !actif))}>
                          {actif ? 'Désactiver' : 'Réactiver'}
                        </button>{' '}
                        <button type="button" className="btn btn-w btn-sm" disabled={enCours}
                          onClick={() => {
                            if (window.confirm(`Supprimer définitivement l'accès de ${m.nom ?? m.email} ?`)) {
                              lancer(() => supprimerMembre(m.id));
                            }
                          }}>
                          Suppr.
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <form action={actionMembre} className="panel">
        <h2>Ajouter un membre</h2>
        {etatMembre?.erreur && <div className="msg ko">{etatMembre.erreur}</div>}
        <div className="row3">
          <div className="field"><label htmlFor="bm-nom">Nom et prénom</label><input id="bm-nom" name="nom" required minLength={2} autoComplete="off" /></div>
          <div className="field"><label htmlFor="bm-email">E-mail (identifiant de connexion)</label><input id="bm-email" name="email" type="email" required autoComplete="off" /></div>
          <div className="field">
            <label htmlFor="bm-poste">Poste</label>
            <select id="bm-poste" name="poste" required defaultValue="">
              <option value="" disabled>Choisir un poste</option>
              {postes.map((p) => <option key={p.cle} value={p.cle}>{p.libelle}</option>)}
              <option value="admin">Administrateur (tout)</option>
            </select>
          </div>
        </div>
        <button className="btn btn-k btn-sm" disabled={envoiMembre}>{envoiMembre ? 'Création…' : "Créer l'accès"}</button>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.9rem' }}>
          Un mot de passe provisoire s&apos;affiche après la création, à transmettre au membre.
        </p>
      </form>

      <div className="panel">
        <h2>Modules par poste</h2>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginBottom: '1rem' }}>
          Coche les modules que chaque poste peut utiliser. Le changement s&apos;applique tout de suite, à la prochaine page ouverte par le membre.
          Les administrateurs ont tout, y compris cet écran.
        </p>
        <div className="tbl-wrap">
          <table className="tbl" style={{ minWidth: 220 + postes.length * 110 }}>
            <thead>
              <tr>
                <th>Module</th>
                {postes.map((p) => (
                  <th key={p.cle} style={{ textAlign: 'center' }}>
                    {p.libelle}
                    {!utilise(p.cle) && (
                      <>
                        {' '}
                        <button type="button" aria-label={`Supprimer le poste ${p.libelle}`} title="Supprimer ce poste" disabled={enCours}
                          onClick={() => { if (window.confirm(`Supprimer le poste « ${p.libelle} » ?`)) lancer(() => supprimerPoste(p.cle)); }}
                          style={{ border: 'none', background: 'none', cursor: 'pointer', fontSize: '.8rem', color: '#6b6560' }}>
                          ✕
                        </button>
                      </>
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {CATEGORIES.map((c) => {
                const groupe = MODULES_ATTRIBUABLES.filter((m) => m.categorie === c.cle);
                if (groupe.length === 0) return null;
                return (
                  <Fragment key={c.cle}>
                    {c.libelle && (
                      <tr><td colSpan={postes.length + 1} style={{ background: '#f4f1ec', fontWeight: 700, fontSize: '.8rem' }}>{c.libelle}</td></tr>
                    )}
                    {groupe.map((m) => (
                      <tr key={m.cle}>
                        <td>{m.libelle}</td>
                        {postes.map((p) => (
                          <td key={p.cle} style={{ textAlign: 'center' }}>
                            <input type="checkbox" aria-label={`${m.libelle} pour ${p.libelle}`}
                              checked={local[`${p.cle}:${m.cle}`] ?? p.modules.includes(m.cle)} style={{ width: 18, height: 18 }}
                              onChange={(e) => basculer(p.cle, m.cle, e.target.checked)} />
                          </td>
                        ))}
                      </tr>
                    ))}
                  </Fragment>
                );
              })}
            </tbody>
          </table>
        </div>

        <form action={actionPoste} style={{ marginTop: '1.4rem' }}>
          {etatPoste?.ok && <div className="msg ok">{etatPoste.ok}</div>}
          {etatPoste?.erreur && <div className="msg ko">{etatPoste.erreur}</div>}
          <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap', alignItems: 'flex-end' }}>
            <div className="field" style={{ flex: '1 1 240px', marginBottom: 0 }}>
              <label htmlFor="bp-libelle">Nouveau poste</label>
              <input id="bp-libelle" name="libelle" placeholder="Ex. Responsable buvette" maxLength={40} required />
            </div>
            <button className="btn btn-y btn-sm" disabled={envoiPoste}>Ajouter le poste</button>
          </div>
        </form>
      </div>
    </>
  );
}
