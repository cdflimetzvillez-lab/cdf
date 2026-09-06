'use client';
import { useState, useTransition } from 'react';
import { basculerModuleTdn } from '@/app/tresors-actions';

export default function BasculeModuleTdn({ actif }: { actif: boolean }) {
  const [confirm, setConfirm] = useState(false);
  const [pending, start] = useTransition();
  return (
    <div className="panel" style={{ borderLeft: `10px solid ${actif ? '#9BD44F' : '#6b6560'}`, opacity: pending ? .7 : 1 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap', alignItems: 'center' }}>
        <div>
          <p style={{ fontFamily: 'Anton, sans-serif', textTransform: 'uppercase', fontSize: '1.3rem' }}>{actif ? '🟢 Module en ligne' : '⚫ Module désactivé'}</p>
          <p style={{ color: '#6b6560', marginTop: '.3rem' }}>
            {actif ? 'Visible dans le menu du site et accessible à l’adresse /tresors-de-noel.' : 'Retiré du menu ; les visiteurs voient « pas disponible pour le moment ». Vous gardez l’accès en tant qu’admin. Aucune donnée n’est supprimée.'}
          </p>
        </div>
        {actif
          ? <button className="btn btn-w btn-sm" onClick={() => setConfirm(true)}>Désactiver le module</button>
          : <button className="btn btn-y btn-sm" onClick={() => start(() => basculerModuleTdn(true))}>Activer le module</button>}
      </div>
      {confirm && (
        <div onClick={() => setConfirm(false)} style={{ position: 'fixed', inset: 0, zIndex: 90, background: 'rgba(20,16,20,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem' }}>
          <div className="panel" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 440, margin: 0 }}>
            <h2>Désactiver les Trésors de Noël ?</h2>
            <p>Le lien disparaît du menu et les pages du jeu ne sont plus accessibles au public. Inscriptions, progressions, clés et lots sont conservés.</p>
            <div style={{ display: 'flex', gap: '.6rem', marginTop: '1.2rem', justifyContent: 'flex-end' }}>
              <button className="btn btn-w btn-sm" onClick={() => setConfirm(false)}>Annuler</button>
              <button className="btn btn-k btn-sm" onClick={() => { setConfirm(false); start(() => basculerModuleTdn(false)); }}>Désactiver</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
