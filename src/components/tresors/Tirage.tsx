'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Neige from './Neige';
import { tirerGrandTresor, annulerTirage, type Gagnant } from '@/app/tresors-actions';
import { numeroCle } from '@/lib/tresors/types';

type CleT = { id: string; numero: number; prenom: string; famille: string };
/** presentation → (balayage → tambour → gagnant) pour chaque lot → final (tous les gagnants). */
type Phase = 'presentation' | 'balayage' | 'tambour' | 'gagnant' | 'final';
type Props = {
  cles: CleT[];
  /** Nombre de lots à attribuer = nombre de clés tirées au sort. */
  nombre: number;
  /** Description de l'ensemble du grand trésor, ex. « 3 cartes cadeaux multi-enseignes de 100 € ». */
  lot: string;
  /** Libellé d'un lot, ex. « Carte cadeau multi-enseignes de 100 € ». */
  lotUnitaire: string;
  tirageFait: boolean;
};

const dodo = (ms: number) => new Promise((r) => setTimeout(r, ms));
const PHRASES = ['Le lutin fouille dans la hotte…', 'Il hésite…', 'Il a trouvé quelque chose…', 'Il la tient !'];

export default function Tirage({ cles, nombre, lot, lotUnitaire, tirageFait }: Props) {
  const [phase, setPhase] = useState<Phase>('presentation');
  const [allumee, setAllumee] = useState<string | null>(null);
  const [chiffres, setChiffres] = useState(['0', '0', '0']);
  const [suspense, setSuspense] = useState(PHRASES[0]);
  const [gagnants, setGagnants] = useState<Gagnant[]>([]);
  const [index, setIndex] = useState(0);
  const [erreur, setErreur] = useState('');
  const [occupe, setOccupe] = useState(false);
  const [deverrouille, setDeverrouille] = useState(!tirageFait);
  const murRef = useRef<HTMLDivElement>(null);

  const total = gagnants.length || Math.min(nombre, Math.max(cles.length, 1));
  const plusieurs = total > 1;
  const gagnant = gagnants[index] ?? null;
  const dejaSorties = new Set(gagnants.slice(0, index).map((g) => g.cleId));

  /** Dévoile le gagnant n° i : balayage du mur de clés, puis tambour chiffre par chiffre. */
  async function devoiler(i: number, liste: Gagnant[]) {
    const g = liste[i];
    if (!g) { setPhase('final'); return; }
    setIndex(i);
    const reduit = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!reduit) {
      setAllumee(null);
      setPhase('balayage');
      const sorties = new Set(liste.slice(0, i).map((x) => x.cleId));
      const enLice = cles.filter((c) => !sorties.has(c.id));
      for (let k = 0; k < 45 && enLice.length > 0; k++) {
        const c = enLice[Math.floor(Math.random() * enLice.length)];
        setAllumee(c.id);
        murRef.current?.querySelector<HTMLElement>(`[data-id="${c.id}"]`)?.scrollIntoView({ block: 'nearest' });
        await dodo(k < 30 ? 45 : 45 + (k - 30) * 25);
      }
      const cible = numeroCle(g.numero).split('');
      const fixes = cible.map(() => '');
      setChiffres(cible.map(() => '0'));
      setPhase('tambour');
      for (let k = 0; k < cible.length; k++) {
        setSuspense(PHRASES[Math.min(k, PHRASES.length - 1)]);
        for (let t = 0; t < 18 + k * 6; t++) {
          setChiffres(fixes.map((f, j) => (j < k ? f : String(Math.floor(Math.random() * 10)))));
          await dodo(70 + k * 30);
        }
        fixes[k] = cible[k];
        setChiffres(fixes.map((f, j) => (j <= k ? cible[j] : f)));
        await dodo(500);
      }
      await dodo(900);
    }
    setPhase('gagnant');
  }

  /** Le serveur décide et enregistre d'abord tous les gagnants ; l'animation ne fait que les dévoiler un par un. */
  async function lancer(direct = false) {
    if (phase !== 'presentation' || occupe) return;
    setErreur(''); setOccupe(true);
    const r = await tirerGrandTresor();
    setOccupe(false);
    if (!r.ok) { setErreur(r.erreur); return; }
    if (r.gagnants.length === 0) { setErreur('Les clés gagnantes sont introuvables. Annulez le tirage et relancez-le.'); return; }
    setGagnants(r.gagnants);
    if (direct) { setIndex(r.gagnants.length - 1); setPhase(r.gagnants.length > 1 ? 'final' : 'gagnant'); return; }
    await devoiler(0, r.gagnants);
  }

  async function relancer() {
    if (!confirm(`Annuler le tirage enregistré et en refaire un ? ${nombre > 1 ? 'Les lots seront retirés aux clés gagnantes actuelles.' : 'Le lot sera retiré à la clé actuelle.'}`)) return;
    await annulerTirage();
    setDeverrouille(true); setGagnants([]); setIndex(0); setPhase('presentation');
  }

  useEffect(() => { document.body.style.overflow = 'hidden'; return () => { document.body.style.overflow = ''; }; }, []);

  const fini = phase === 'gagnant' || phase === 'final';
  const titre = 'Le tirage du Grand Trésor';
  const etape = plusieurs ? `Grand Trésor · lot ${index + 1} sur ${total}` : null;

  return (
    <main className={`tdn-tirage${fini ? ' fini' : ''}${phase === 'presentation' || phase === 'final' ? ' defile' : ''}`}>
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={45} />
      <div className="tdn-tirage-halo" aria-hidden="true" />
      <div className="tdn-tirage-admin">
        <span>Écran admin</span>
        <span>{fini ? 'Tirage enregistré' : tirageFait && !deverrouille ? 'Tirage déjà effectué' : `${cles.length} clés en lice`}</span>
        <Link href="/tresors-de-noel/revelation">Écran de révélation</Link>
      </div>

      {phase === 'presentation' && (
        <section className="tdn-tirage-inner">
          <div className="tdn-sur tdn-sur-grand">Les Trésors de Noël de Limetz-Villez</div>
          <h1 className="tdn-rev-titre">{titre}</h1>
          <p className="tdn-rev-sous">
            {lot}. {nombre > 1 ? `${nombre} clés différentes sont tirées au sort parmi toutes les clés du jeu, une par lot.` : 'Toutes les clés générées pendant le jeu participent au tirage.'}
          </p>
          <p className="tdn-tirage-compteur"><b>{cles.length}</b> clé{cles.length > 1 ? 's' : ''} en lice</p>
          <div className="tdn-mur" ref={murRef}>
            {cles.map((c) => <div key={c.id} data-id={c.id} className="tdn-cle-tuile">{numeroCle(c.numero)}<small>{c.prenom}</small></div>)}
          </div>
          {cles.length > 0 && cles.length < nombre && <p className="tdn-erreur">Seulement {cles.length} clé{cles.length > 1 ? 's' : ''} en lice pour {nombre} lots : {cles.length > 1 ? `${cles.length} lots seront attribués` : 'un seul lot sera attribué'}.</p>}
          {erreur && <p className="tdn-erreur" role="alert">{erreur}</p>}
          {tirageFait && !deverrouille ? (
            <div className="tdn-actions tdn-actions-col" style={{ maxWidth: '28rem', margin: '1.5rem auto 0' }}>
              <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={() => lancer()} disabled={occupe}>Revoir le résultat</button>
              {nombre > 1 && <button className="tdn-btn tdn-btn-ghost" onClick={() => lancer(true)} disabled={occupe}>Afficher directement les gagnants</button>}
              <button className="tdn-btn tdn-btn-ghost" onClick={relancer} disabled={occupe}>Annuler et refaire le tirage</button>
            </div>
          ) : (
            <button className="tdn-btn tdn-btn-or tdn-btn-xl" style={{ maxWidth: '28rem', margin: '1.5rem auto 0' }} onClick={() => lancer()} disabled={cles.length === 0 || occupe}>
              {occupe ? 'Tirage en cours…' : 'Lancer le tirage'}
            </button>
          )}
        </section>
      )}

      {phase === 'balayage' && (
        <section className="tdn-tirage-inner">
          {etape && <div className="tdn-tirage-etape">{etape}</div>}
          <h1 className="tdn-rev-titre">{titre}</h1>
          <div className="tdn-mur" ref={murRef}>
            {cles.map((c) => (
              <div key={c.id} data-id={c.id} className={`tdn-cle-tuile${allumee === c.id ? ' on' : ''}${dejaSorties.has(c.id) ? ' tiree' : ''}`}>
                {numeroCle(c.numero)}<small>{c.prenom}</small>
              </div>
            ))}
          </div>
        </section>
      )}

      {phase === 'tambour' && (
        <section className="tdn-tirage-inner">
          {etape && <div className="tdn-tirage-etape">{etape}</div>}
          <div className="tdn-sur tdn-sur-grand">Clé n°</div>
          <div className="tdn-tambour">{chiffres.map((c, i) => <span key={i}>{c}</span>)}</div>
          <p className="tdn-rev-sous" style={{ marginTop: '1.5rem' }}>{suspense}</p>
        </section>
      )}

      {phase === 'gagnant' && gagnant && (
        <section className="tdn-tirage-inner tdn-tirage-resultat" key={gagnant.cleId}>
          <div className="tdn-particules" aria-hidden="true">{Array.from({ length: 40 }).map((_, i) => <i key={i} style={{ left: `${(i * 41) % 100}%`, animationDelay: `${(i % 8) * .15}s` }} />)}</div>
          {etape && <div className="tdn-tirage-etape">{etape}</div>}
          <div className="tdn-sur tdn-sur-grand">{plusieurs ? 'Ce lot revient à' : 'Le Grand Trésor revient à'}</div>
          <div className="tdn-gagnant">
            <div className="tdn-gagnant-num">Clé n° {numeroCle(gagnant.numero)}</div>
            <div className="tdn-gagnant-nom">{gagnant.prenom}</div>
            {gagnant.famille && <div className="tdn-gagnant-famille">Famille {gagnant.famille}</div>}
          </div>
          {plusieurs ? (
            <>
              <p className="tdn-gagnant-lot">{lotUnitaire}</p>
              <div className="tdn-actions tdn-actions-col" style={{ width: '100%', maxWidth: '28rem', margin: '1.2rem auto 0' }}>
                {index < total - 1
                  ? <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={() => devoiler(index + 1, gagnants)}>Tirer le lot n° {index + 2}</button>
                  : <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={() => setPhase('final')}>Voir les {total} gagnants</button>}
              </div>
            </>
          ) : (
            <>
              <div className="tdn-lot" style={{ marginTop: '1rem' }}>{lot}</div>
              <p className="tdn-rev-sous">Félicitations, et merci d&apos;avoir joué avec nous !</p>
              <Link href="/tresors-de-noel/revelation" className="tdn-btn tdn-btn-ghost">Retour à l&apos;écran de révélation</Link>
            </>
          )}
        </section>
      )}

      {phase === 'final' && (
        <section className="tdn-tirage-inner tdn-tirage-resultat">
          <div className="tdn-particules" aria-hidden="true">{Array.from({ length: 40 }).map((_, i) => <i key={i} style={{ left: `${(i * 41) % 100}%`, animationDelay: `${(i % 8) * .15}s` }} />)}</div>
          <div className="tdn-sur tdn-sur-grand">Le Grand Trésor revient à</div>
          <div className="tdn-podium">
            {gagnants.map((g, i) => (
              <div className="tdn-gagnant" key={g.cleId}>
                <div className="tdn-gagnant-rang">Lot {i + 1}</div>
                <div className="tdn-gagnant-num">Clé n° {numeroCle(g.numero)}</div>
                <div className="tdn-gagnant-nom">{g.prenom}</div>
                {g.famille && <div className="tdn-gagnant-famille">Famille {g.famille}</div>}
              </div>
            ))}
          </div>
          <div className="tdn-lot tdn-lot-recap">{lot}</div>
          <p className="tdn-rev-sous">Félicitations, et merci d&apos;avoir joué avec nous !</p>
          <Link href="/tresors-de-noel/revelation" className="tdn-btn tdn-btn-ghost">Retour à l&apos;écran de révélation</Link>
        </section>
      )}
    </main>
  );
}
