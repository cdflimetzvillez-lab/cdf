'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function MenuButton({ tresors = true }: { tresors?: boolean }) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : '';
    const esc = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    window.addEventListener('keydown', esc);
    return () => {
      window.removeEventListener('keydown', esc);
      document.body.style.overflow = '';
    };
  }, [open]);

  return (
    <>
      <button
        className="menu-btn"
        onClick={() => setOpen(true)}
        aria-expanded={open}
        aria-label="Ouvrir le menu"
      >
        <span className="bars" aria-hidden="true"><i /><i /><i /></span>
        <span className="menu-word">Menu</span>
      </button>

      {open && (
        <div className="menu-panel" role="dialog" aria-modal="true" aria-label="Menu principal">
          <button className="menu-close" onClick={() => setOpen(false)} aria-label="Fermer le menu">
            ✕
          </button>
          <nav className="menu-nav" onClick={() => setOpen(false)}>
            <Link href="/">Accueil</Link>
            <Link href="/#evenements">Programme</Link>
            {tresors && <Link href="/tresors-de-noel">Trésors de Noël</Link>}
            <Link href="/#association">L&apos;association</Link>
            <Link href="/#benevoles">Bénévoles</Link>
          </nav>
          <div className="menu-foot mono">
            Comité des Fêtes de Limetz-Villez · Association loi 1901
          </div>
        </div>
      )}
    </>
  );
}
