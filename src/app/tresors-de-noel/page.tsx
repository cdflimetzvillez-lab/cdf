'use client';
import { useEffect, useState } from 'react';
import Intro from '@/components/tresors/Intro';
import Landing from '@/components/tresors/Landing';
import NavTresors from '@/components/tresors/NavTresors';

const CLE_INTRO = 'tdn-intro-vue';

export default function PageTresors() {
  // null = indéterminé (évite un flash côté serveur), true = jouer l'intro
  const [intro, setIntro] = useState<boolean | null>(null);

  useEffect(() => {
    setIntro(sessionStorage.getItem(CLE_INTRO) !== '1');
  }, []);

  function finIntro() {
    sessionStorage.setItem(CLE_INTRO, '1');
    setIntro(false);
  }

  if (intro === null) return <div className="tdn-fond-nuit" style={{ minHeight: '100vh' }} />;
  if (intro) return <Intro onFin={finIntro} />;

  return (
    <>
      <Landing />
      <NavTresors />
    </>
  );
}
