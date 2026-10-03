'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { CATEGORIES, MODULES, moduleDuChemin } from '@/lib/bureau/modules';
import './nav-admin.css';

/** Menu de l'admin, rangé par catégories et limité aux modules accordés au membre connecté. */
export default function NavAdmin({ modules }: { modules: string[] }) {
  const path = usePathname();
  const [ouvert, setOuvert] = useState(false);
  useEffect(() => { setOuvert(false); }, [path]);

  const liens = MODULES.filter((m) => modules.includes(m.cle));
  const actif = moduleDuChemin(path);
  const courant = liens.find((l) => l.cle === actif)?.libelle ?? 'Menu';

  return (
    <nav className={`adm-nav${ouvert ? ' ouvert' : ''}`}>
      <button type="button" className="adm-nav-btn" aria-expanded={ouvert} onClick={() => setOuvert((v) => !v)}>
        <span>{courant}</span>
        <span aria-hidden="true">{ouvert ? '✕' : '☰'}</span>
      </button>
      <div className="adm-nav-liens">
        {CATEGORIES.map((c) => {
          const groupe = liens.filter((l) => l.categorie === c.cle);
          if (groupe.length === 0) return null;
          return (
            <div key={c.cle} className="adm-groupe">
              {c.libelle && <div className="adm-cat">{c.libelle}</div>}
              {groupe.map((l) => (
                <Link key={l.chemin} href={l.chemin} className={l.cle === actif ? 'on' : ''}>
                  {l.libelle}
                </Link>
              ))}
            </div>
          );
        })}
      </div>
    </nav>
  );
}
