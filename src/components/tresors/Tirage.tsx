'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Neige from './Neige';
import { tirerGrandTresor, annulerTirage, type ResultatTirage } from '@/app/tresors-actions';
import { numeroCle } from '@/lib/tresors/types';

type CleT = { id: string; numero: number; prenom: string; famille: string };
type Phase = 'presentation' | 'balayage' | 'tambour' | 'resultat';

const dodo = (ms: number) => new Promise((r) => setTimeout(r, ms));

export default function Tirage({ cles, lot, tirageFait }: { cles: CleT[]; lot: string; tirageFait: boolean }) {
  const [phase, setPhase] = useState<Phase>('presentation');
  const [allumee, setAllumee] = useState<string | null>(null);
  const [chiffres, setChiffres] = useState(['0', '0', '0']);
  const [suspense, setSuspense] = useState('Le lutin fouille dans la hotte…');
  const [gagnant, setGagnant] = useState<Extract<ResultatTirage, { ok: true }> | null>(null);
  const [erreur, setErreur] = useState('');
  const [deverrouille, setDeverrouille] = useState(!tirageFait);
  const murRef = useRef<HTMLDivElement>(null);

  async function lancer() {
    if (phase !== 'presentation') return;
    setErreur('');
    // Le serveur décide et enregistre d'abord ; l'animation ne fait que dévoiler.
    const r = await tirerGrandTresor();
    if (!r.ok) { setErreur(r.erreur); return; }
    setGagnant(r);
    setPhase('balayage');
    const reduit = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!reduit) {
      for (let i = 0; i < 45; i++) {
        const c = cles[Math.floor(Math.random() * cles.length)];
        setAllumee(c.id);
        murRef.current?.querySelector<HTMLElement>(`[data-id="${c.id}"]`)?.scrollIntoView({ block: 'nearest' });
        await dodo(i < 30 ? 45 : 45 + (i - 30) * 25);
      }
      setPhase('tambour');
      const cible = numeroCle(r.numero).split('');
      const phrases = ['Le lutin fouille dans la hotte…', 'Il hésite…', 'Il a trouvé quelque chose…'];
      const fixes = ['', '', ''];
      for (let k = 0; k < 3; k++) {
        setSuspense(phrases[k]);
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
    setPhase('resultat');
  }

  async function relancer() {
    if (!confirm('Annuler le tirage enregistré et en refaire un ? Le lot sera retiré à la clé actuelle.')) return;
    await annulerTirage();
    setDeverrouille(true); setGagnant(null); setPhase('presentation');
  }

  useEffect(() => { document.body.style.overflow = 'hidden'; return () => { document.body.style.overflow = ''; }; }, []);

  return (
    <main className={`tdn-tirage${phase === 'resultat' ? ' fini' : ''}`}>
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={45} />
      <div className="tdn-tirage-halo" aria-hidden="true" />
      <div className="tdn-tirage-admin">
        <span>Écran admin</span>
        <span>{phase === 'resultat' ? 'Tirage enregistré' : tirageFait && !deverrouille ? 'Tirage déjà effectué' : `${cles.length} clés en lice`}</span>
        <Link href="/tresors-de-noel/revelation">Écran de révélation</Link>
      </div>

      {phase === 'presentation' && (
        <section className="tdn-tirage-inner">
          <div className="tdn-sur tdn-sur-grand">Les Trésors de Noël de Limetz-Villez</div>
          <h1 className="tdn-rev-titre">Le tirage du Grand Trésor</h1>
          <p className="tdn-rev-sous">{lot}. Toutes les clés générées pendant le jeu participent au tirage.</p>
          <p className="tdn-tirage-compteur"><b>{cles.length}</b> clé{cles.length > 1 ? 's' : ''} en lice</p>
          <div className="tdn-mur" ref={murRef}>
            {cles.map((c) => <div key={c.id} data-id={c.id} className="tdn-cle-tuile">{numeroCle(c.numero)}<small>{c.prenom}</small></div>)}
          </div>
          {erreur && <p className="tdn-erreur">{erreur}</p>}
          {tirageFait && !deverrouille ? (
            <div className="tdn-actions tdn-actions-col" style={{ maxWidth: '28rem', margin: '1.5rem auto 0' }}>
              <button className="tdn-btn tdn-btn-or tdn-btn-xl" onClick={lancer}>Revoir le résultat</button>
              <button className="tdn-btn tdn-btn-ghost" onClick={relancer}>Annuler et refaire le tirage</button>
            </div>
          ) : (
            <button className="tdn-btn tdn-btn-or tdn-btn-xl" style={{ maxWidth: '28rem', margin: '1.5rem auto 0' }} onClick={lancer} disabled={cles.length === 0}>Lancer le tirage</button>
          )}
        </section>
      )}

      {phase === 'balayage' && (
        <section className="tdn-tirage-inner">
          <h1 className="tdn-rev-titre">Le tirage du Grand Trésor</h1>
          <div className="tdn-mur" ref={murRef}>
            {cles.map((c) => <div key={c.id} data-id={c.id} className={`tdn-cle-tuile${allumee === c.id ? ' on' : ''}`}>{numeroCle(c.numero)}<small>{c.prenom}</small></div>)}
          </div>
        </section>
      )}

      {phase === 'tambour' && (
        <section className="tdn-tirage-inner">
          <div className="tdn-sur tdn-sur-grand">Clé n°</div>
          <div className="tdn-tambour">{chiffres.map((c, i) => <span key={i}>{c}</span>)}</div>
          <p className="tdn-rev-sous" style={{ marginTop: '1.5rem' }}>{suspense}</p>
        </section>
      )}

      {phase === 'resultat' && gagnant && (
        <section className="tdn-tirage-inner tdn-tirage-resultat">
          <div className="tdn-particules" aria-hidden="true">{Array.from({ length: 40 }).map((_, i) => <i key={i} style={{ left: `${(i * 41) % 100}%`, animationDelay: `${(i % 8) * .15}s` }} />)}</div>
          <div className="tdn-sur tdn-sur-grand">Le Grand Trésor revient à</div>
          <div className="tdn-gagnant">
            <div className="tdn-gagnant-num">Clé n° {numeroCle(gagnant.numero)}</div>
            <div className="tdn-gagnant-nom">{gagnant.prenom}</div>
            {gagnant.famille && <div className="tdn-gagnant-famille">Famille {gagnant.famille}</div>}
          </div>
          <div className="tdn-lot" style={{ marginTop: '1rem' }}>{lot}</div>
          <p className="tdn-rev-sous">Félicitations, et merci d&apos;avoir joué avec nous !</p>
          <Link href="/tresors-de-noel/revelation" className="tdn-btn tdn-btn-ghost">Retour à l&apos;écran de révélation</Link>
        </section>
      )}
    </main>
  );
}
