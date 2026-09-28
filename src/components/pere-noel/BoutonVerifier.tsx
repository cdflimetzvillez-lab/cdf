'use client';
import { useEffect, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { verifierToutes } from '@/app/pere-noel-actions';

/** Vérifie les vidéos en cours et lance les commandes en attente (si auto). Se relance seul toutes les 60 s tant que la page est ouverte. */
export default function BoutonVerifier({ auto = true }: { auto?: boolean }) {
  const [pending, start] = useTransition();
  const [info, setInfo] = useState('');
  const router = useRouter();
  const lancer = () => start(async () => {
    const r = await verifierToutes();
    setInfo(`${r.verifiees} vérifiée${r.verifiees > 1 ? 's' : ''}, ${r.lancees} lancée${r.lancees > 1 ? 's' : ''}`);
    router.refresh();
  });
  useEffect(() => {
    if (!auto) return;
    const t = setInterval(lancer, 60_000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [auto]);
  return (
    <button className="btn btn-y btn-sm" onClick={lancer} disabled={pending} title={info}>
      {pending ? 'Vérification…' : '↻ Vérifier les vidéos'}
    </button>
  );
}
