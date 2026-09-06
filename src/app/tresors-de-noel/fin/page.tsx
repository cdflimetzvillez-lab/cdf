'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import Neige from '@/components/tresors/Neige';
import CarteCle from '@/components/tresors/CarteCle';
import { useTresors } from '@/lib/tresors/store';
import { EVENEMENT } from '@/lib/tresors/mock';

/** Écran de fin spectaculaire : séquence de textes → coffre → clé. */
export default function PageFin() {
  const { participantActif, progressionActive } = useTresors();
  const cle = progressionActive.cle;
  const [etape, setEtape] = useState(0);
  const [vueCle, setVueCle] = useState(false);

  useEffect(() => {
    const reduit = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduit) { setEtape(3); return; }
    const t = [setTimeout(() => setEtape(1), 1800), setTimeout(() => setEtape(2), 3600), setTimeout(() => setEtape(3), 5600)];
    return () => t.forEach(clearTimeout);
  }, []);

  if (!cle) {
    return (
      <main className="tdn-page tdn-centre">
        <h1 className="tdn-titre-fee">Pas encore…</h1>
        <p className="tdn-p">{participantActif.prenom} n&apos;a pas encore résolu les {EVENEMENT.nbMissions} mystères.</p>
        <Link href="/tresors-de-noel/aventure" className="tdn-btn tdn-btn-or">Retour à l&apos;aventure</Link>
      </main>
    );
  }

  return (
    <main className="tdn-fin">
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={45} />
      {etape >= 2 && <div className="tdn-lumiere-or" aria-hidden="true" />}

      <div className="tdn-fin-inner" aria-live="polite">
        {etape === 0 && <p className="tdn-fin-texte tdn-titre-fee">Vous l&apos;avez fait.</p>}
        {etape === 1 && <p className="tdn-fin-texte tdn-titre-fee">Les 12 mystères de Noël ont été résolus.</p>}
        {etape === 2 && (
          <div className="tdn-coffre-scene">
            <div className="tdn-coffre ouvert" aria-hidden="true"><i className="tdn-coffre-couvercle" /><i className="tdn-coffre-corps" /><i className="tdn-coffre-lueur" /></div>
            <p className="tdn-fin-texte tdn-titre-fee">Votre clé virtuelle vient d&apos;être créée.</p>
          </div>
        )}
        {etape >= 3 && (
          <div className="tdn-fin-cle">
            {!vueCle ? (
              <>
                <p className="tdn-fin-texte tdn-titre-fee">Votre clé virtuelle vient d&apos;être créée.</p>
                <button className="tdn-btn tdn-btn-or tdn-btn-large" onClick={() => setVueCle(true)}>Voir ma clé</button>
              </>
            ) : (
              <>
                <CarteCle cle={cle} prenom={participantActif.prenom} grande />
                <p className="tdn-fin-msg">
                  Gardez-la précieusement. Vous pourrez découvrir votre trésor lors du Marché de Noël de Limetz-Villez.
                </p>
                <div className="tdn-actions tdn-actions-col">
                  <button className="tdn-btn tdn-btn-or tdn-btn-large" onClick={() => alert('Démo : la clé serait ajoutée à votre portefeuille.')}>
                    Enregistrer ma clé
                  </button>
                  <Link href="/tresors-de-noel/cle" className="tdn-btn tdn-btn-ghost">Aller à « Ma clé »</Link>
                </div>
                <p className="tdn-muted tdn-mini">Votre clé reste disponible à tout moment dans votre compte.</p>
              </>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
