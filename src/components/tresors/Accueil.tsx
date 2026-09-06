'use client';
import { useEffect, useState } from 'react';
import Intro from './Intro';
import Landing from './Landing';
import NavTresors from './NavTresors';
import type { Reglages } from '@/lib/tresors/types';

const CLE_INTRO = 'tdn-intro-vue';

/** Joue l'intro une seule fois par session, puis affiche la landing. */
export default function Accueil({ reglages, connecte }: { reglages: Reglages; connecte: boolean }) {
  const [intro, setIntro] = useState<boolean | null>(null);
  useEffect(() => { setIntro(sessionStorage.getItem(CLE_INTRO) !== '1'); }, []);

  function finIntro() { sessionStorage.setItem(CLE_INTRO, '1'); setIntro(false); }

  if (intro === null) return <div className="tdn-fond-nuit" style={{ minHeight: '100vh' }} />;
  if (intro) return <Intro titre={reglages.titre} onFin={finIntro} />;
  return (
    <>
      <Landing reglages={reglages} connecte={connecte} />
      <NavTresors />
    </>
  );
}
