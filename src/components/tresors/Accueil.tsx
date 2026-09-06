'use client';
import { useEffect, useState } from 'react';
import Intro from './Intro';
import Landing from './Landing';
import LandingReservation from './LandingReservation';
import NavTresors from './NavTresors';
import type { Reglages } from '@/lib/tresors/types';

const CLE_INTRO = 'tdn-intro-vue';

type Props = { reglages: Reglages; connecte: boolean; phase: 'reservation' | 'jeu'; placesRestantes: number };

/** Joue l'intro une seule fois par session, puis affiche la page selon la phase (réservation ou jeu). */
export default function Accueil({ reglages, connecte, phase, placesRestantes }: Props) {
  const [intro, setIntro] = useState<boolean | null>(null);
  useEffect(() => { setIntro(sessionStorage.getItem(CLE_INTRO) !== '1'); }, []);
  function finIntro() { sessionStorage.setItem(CLE_INTRO, '1'); setIntro(false); }

  if (intro === null) return <div className="tdn-fond-nuit" style={{ minHeight: '100vh' }} />;
  if (intro) return <Intro titre={reglages.titre} onFin={finIntro} />;
  if (phase === 'reservation') return <LandingReservation reglages={reglages} connecte={connecte} placesRestantes={placesRestantes} />;
  return (
    <>
      <Landing reglages={reglages} connecte={connecte} />
      <NavTresors />
    </>
  );
}
