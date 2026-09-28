'use client';
import { useActionState, useEffect, useState } from 'react';
import { commander, type Etat } from '@/app/pere-noel-actions';
import { euros } from '@/lib/sumup';
import { LIBELLE_SAGESSE, type Sagesse, type TonSecret } from '@/lib/pere-noel/types';

const EFFORTS = ['Dormir dans son lit', 'Goûter les légumes', 'Ranger sa chambre', 'Être gentil avec son frère ou sa sœur', 'Moins d’écrans', 'Se brosser les dents sans râler'];
const NOMS_ETAPES = ['L’enfant', 'Sa lettre', 'Les détails', 'Le secret', 'Récapitulatif'];

export default function FormCommande({ prix, test }: { prix: number; test: boolean }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(commander, null);
  const [etape, setEtape] = useState(1);
  useEffect(() => { if (typeof window !== 'undefined') window.scrollTo({ top: 0, behavior: 'smooth' }); }, [etape]);
  const [f, setF] = useState({
    enfant_prenom: '', prononciation: '', age: '', genre: '', sagesse: 'tres_sage' as Sagesse,
    lettre: '', cadeaux: '', fierte: '', passion: '', effort: '', effortAutre: '', salut: '',
    secret: '', ton_secret: 'rigolo' as TonSecret, parent_prenom: '', email: '',
  });
  const maj = (k: keyof typeof f, v: string) => setF((x) => ({ ...x, [k]: v }));
  const enfantOk = f.enfant_prenom.trim().length > 0 && Number(f.age) > 0;
  const lettreOk = f.lettre.trim().length > 0 || f.cadeaux.trim().length > 0;
  const parentOk = f.parent_prenom.trim().length > 0 && f.email.includes('@');
  const effortFinal = f.effort === 'autre' ? f.effortAutre : f.effort;

  return (
    <form action={action}>
      <input type="hidden" name="test" value={test ? '1' : '0'} />
      <input type="hidden" name="effort" value={effortFinal} />
      <div className="pn-steps" aria-hidden="true">{[1, 2, 3, 4, 5].map((n) => <i key={n} className={n <= etape ? 'on' : ''} />)}</div>
      <div className="pn-stepname">Étape {etape} sur 5 · {NOMS_ETAPES[etape - 1]}</div>
      {etat?.erreur && <p className="pn-erreur" role="alert">{etat.erreur}</p>}
      {test && <p className="pn-cardn pn-mini">Mode test administrateur : pas de paiement, la commande est créée directement.</p>}

      {/* 1. L'enfant */}
      <section className="pn-carte" hidden={etape !== 1}>
        <h2>Pour qui est cette vidéo ?</h2>
        <p className="pn-l">Le Père Noël prononcera son prénom, écrivez-le comme on le dit.</p>
        <div className="pn-champ"><label htmlFor="enfant_prenom">Prénom de l&apos;enfant</label>
          <input id="enfant_prenom" name="enfant_prenom" value={f.enfant_prenom} onChange={(e) => maj('enfant_prenom', e.target.value)} autoComplete="off" /></div>
        <div className="pn-champ"><label htmlFor="prononciation">Comment on le prononce (si besoin)</label>
          <input id="prononciation" name="prononciation" placeholder="Ex. : Maël se dit « Ma-el »" value={f.prononciation} onChange={(e) => maj('prononciation', e.target.value)} /></div>
        <div className="pn-row">
          <div className="pn-champ"><label htmlFor="age">Âge</label>
            <input id="age" name="age" type="number" inputMode="numeric" min={1} max={17} value={f.age} onChange={(e) => maj('age', e.target.value)} /></div>
          <div className="pn-champ"><label htmlFor="genre">Fille ou garçon</label>
            <select id="genre" name="genre" value={f.genre} onChange={(e) => maj('genre', e.target.value)}>
              <option value="">Je préfère ne pas dire</option><option value="fille">Fille</option><option value="garcon">Garçon</option></select></div>
        </div>
        <div className="pn-champ"><label>A-t-il été sage cette année ?</label>
          <div className="pn-opts">
            {([['presque', '~'], ['tres_sage', '★'], ['le_plus_sage', '★★']] as [Sagesse, string][]).map(([v, s]) => (
              <label key={v} className={f.sagesse === v ? 'on' : ''}><input type="radio" name="sagesse" value={v} checked={f.sagesse === v} onChange={() => maj('sagesse', v)} /><b>{s}</b>{LIBELLE_SAGESSE[v]}</label>
            ))}
          </div></div>
        <button type="button" className="pn-btn" disabled={!enfantOk} onClick={() => setEtape(2)}>Continuer</button>
      </section>

      {/* 2. Sa lettre */}
      <section className="pn-carte" hidden={etape !== 2}>
        <h2>Qu&apos;est-ce que {f.enfant_prenom || 'votre enfant'} veut dire au Père Noël ?</h2>
        <p className="pn-l">Écrivez ce qu&apos;il vous dicte, avec ses mots. C&apos;est à cette lettre que le Père Noël va répondre. S&apos;il pose une question, le Père Noël y répondra.</p>
        <div className="pn-champ"><label htmlFor="lettre">Sa lettre</label>
          <textarea id="lettre" name="lettre" placeholder="Cher Père Noël, cette année j'ai appris à…" value={f.lettre} onChange={(e) => maj('lettre', e.target.value)} maxLength={1500} /></div>
        <div className="pn-champ"><label htmlFor="cadeaux">Ce qu&apos;il demande comme cadeau (pour que le Père Noël en parle)</label>
          <input id="cadeaux" name="cadeaux" placeholder="Un microscope, un livre sur les dauphins" value={f.cadeaux} onChange={(e) => maj('cadeaux', e.target.value)} /></div>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(1)}>Retour</button>
          <button type="button" className="pn-btn" disabled={!lettreOk} onClick={() => setEtape(3)}>Continuer</button>
        </div>
      </section>

      {/* 3. Les détails */}
      <section className="pn-carte" hidden={etape !== 3}>
        <h2>Ce que le Père Noël sait sur {f.enfant_prenom || 'lui'}</h2>
        <p className="pn-l">Tout est facultatif. Plus vous remplissez, plus la vidéo est bluffante.</p>
        <div className="pn-champ"><label htmlFor="fierte">Sa grande fierté de l&apos;année</label>
          <input id="fierte" name="fierte" placeholder="A appris à faire du vélo sans les petites roues" value={f.fierte} onChange={(e) => maj('fierte', e.target.value)} /></div>
        <div className="pn-champ"><label htmlFor="passion">Son doudou, son animal ou sa passion</label>
          <input id="passion" name="passion" placeholder="Son lapin Caramel et les dauphins" value={f.passion} onChange={(e) => maj('passion', e.target.value)} /></div>
        <div className="pn-champ"><label>Un petit effort à encourager (le Père Noël le demande gentiment)</label>
          <div className="pn-chips">
            {EFFORTS.map((e) => <label key={e} className={f.effort === e ? 'on' : ''}><input type="radio" name="effort_choix" checked={f.effort === e} onChange={() => maj('effort', e)} />{e}</label>)}
            <label className={f.effort === 'autre' ? 'on' : ''}><input type="radio" name="effort_choix" checked={f.effort === 'autre'} onChange={() => maj('effort', 'autre')} />Autre…</label>
            {f.effort && <label className="on" style={{ background: 'transparent', color: 'var(--pn-encre2)', borderStyle: 'dashed' }} onClick={() => maj('effort', '')}>✕ aucun</label>}
          </div>
          {f.effort === 'autre' && <input style={{ marginTop: 8 }} placeholder="Ex. : arrêter de mordre son frère" value={f.effortAutre} onChange={(e) => maj('effortAutre', e.target.value)} />}
        </div>
        <div className="pn-champ"><label htmlFor="salut">Une personne à saluer (mamie, la maîtresse, le petit frère…)</label>
          <input id="salut" name="salut" placeholder="Mamie Jacqueline" value={f.salut} onChange={(e) => maj('salut', e.target.value)} /></div>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(2)}>Retour</button>
          <button type="button" className="pn-btn" onClick={() => setEtape(4)}>Continuer</button>
        </div>
      </section>

      {/* 4. Le secret */}
      <section className="pn-carte" hidden={etape !== 4}>
        <h2>Un mot que seul le Père Noël pouvait connaître</h2>
        <p className="pn-l">Un détail que votre enfant n&apos;a dit à personne, une petite bêtise pardonnée, un souvenir… Le Père Noël le glisse dans la vidéo. C&apos;est ce qui le fera écarquiller les yeux. Facultatif.</p>
        <div className="pn-champ"><label htmlFor="secret">Le message secret</label>
          <textarea id="secret" name="secret" placeholder="Elle a caché les bonbons d'Halloween dans sa boîte à chaussures et pense que personne ne le sait." value={f.secret} onChange={(e) => maj('secret', e.target.value)} maxLength={500} style={{ minHeight: 90 }} /></div>
        <div className="pn-champ"><label>Comment le Père Noël doit le dire</label>
          <div className="pn-opts">
            {([['rigolo', '☺', 'En rigolant'], ['tendre', '♥', 'Avec tendresse'], ['serieux', '!', 'Un peu sérieux']] as [TonSecret, string, string][]).map(([v, s, l]) => (
              <label key={v} className={f.ton_secret === v ? 'on' : ''}><input type="radio" name="ton_secret" value={v} checked={f.ton_secret === v} onChange={() => maj('ton_secret', v)} /><b>{s}</b>{l}</label>
            ))}
          </div></div>
        <p className="pn-l pn-mini" style={{ marginTop: 12 }}>Le message secret n&apos;apparaît que dans la vidéo, jamais sur la lettre ni le certificat.</p>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(3)}>Retour</button>
          <button type="button" className="pn-btn" onClick={() => setEtape(5)}>Continuer</button>
        </div>
      </section>

      {/* 5. Récap + parent */}
      <section className="pn-carte" hidden={etape !== 5}>
        <h2>On envoie la lettre de {f.enfant_prenom || 'votre enfant'} ?</h2>
        <dl className="pn-recap" style={{ margin: 0 }}>
          <dt>Pour</dt><dd>{f.enfant_prenom}, {f.age} ans, {LIBELLE_SAGESSE[f.sagesse]}</dd>
          {(f.fierte || f.passion || f.salut || effortFinal) && <><dt>Le Père Noël va parler de</dt><dd>{[f.fierte, f.passion, f.salut, effortFinal].filter(Boolean).join(' · ')}</dd></>}
          {f.secret && <><dt>Message secret</dt><dd>Oui, {({ rigolo: 'en rigolant', tendre: 'avec tendresse', serieux: 'un peu sérieux' })[f.ton_secret]}</dd></>}
        </dl>
        <div className="pn-champ"><label htmlFor="parent_prenom">Votre prénom</label>
          <input id="parent_prenom" name="parent_prenom" autoComplete="given-name" value={f.parent_prenom} onChange={(e) => maj('parent_prenom', e.target.value)} /></div>
        <div className="pn-champ"><label htmlFor="email">Votre email (pour recevoir la vidéo)</label>
          <input id="email" name="email" type="email" inputMode="email" autoComplete="email" value={f.email} onChange={(e) => maj('email', e.target.value)} /></div>
        <div style={{ marginTop: 14 }}>
          <div className="pn-prix"><span>Vidéo réponse du Père Noël</span><span>{test ? 'test' : euros(prix)}</span></div>
          <div className="pn-prix"><span>Lettre écrite + certificat d&apos;enfant sage</span><span>inclus</span></div>
          <div className="pn-prix total"><span>Total</span><span>{test ? '0 €' : euros(prix)}</span></div>
        </div>
        <button type="submit" className="pn-btn vert" disabled={!parentOk || pending}>
          {pending ? 'Redirection…' : test ? 'Créer la commande de test' : `Payer ${euros(prix)} par carte`}
        </button>
        <p className="pn-l pn-mini pn-centre" style={{ marginTop: 10 }}>Paiement sécurisé par SumUp. Vidéo livrée par email, garantie satisfait ou refait.</p>
        <button type="button" className="pn-lien" onClick={() => setEtape(1)}>Modifier les réponses</button>
      </section>
    </form>
  );
}
