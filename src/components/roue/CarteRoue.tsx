'use client';
import { useState, useTransition } from 'react';
import Link from 'next/link';
import { basculerRoue } from '@/app/roue-actions';
import type { ModuleAccueil, StatsRoue } from '@/lib/roue/types';

const fmt = (iso: string | null) => iso ? new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', timeZone: 'Europe/Paris' }).format(new Date(iso)) : '—';
const n = (v?: number) => (v ?? 0).toLocaleString('fr-FR');

export default function CarteRoue({ module: m, visible, stats, onglet }: { module: ModuleAccueil; visible: boolean; stats: Partial<StatsRoue>; onglet: string }) {
  const [confirm, setConfirm] = useState(false);
  const [message, setMessage] = useState('');
  const [pending, start] = useTransition();

  function basculer(active: boolean) {
    setConfirm(false);
    start(async () => { const r = await basculerRoue(active); setMessage(r?.ok ?? r?.erreur ?? ''); });
  }

  const ONGLETS = [
    { k: 'apercu', l: 'Aperçu' }, { k: 'parametres', l: 'Paramètres' }, { k: 'lots', l: 'Gérer les lots' }, { k: 'gagnants', l: 'Voir les gagnants' },
  ];

  return (
    <div className="panel" style={{ borderLeft: `10px solid ${m.is_active ? '#9BD44F' : '#6b6560'}`, opacity: pending ? .7 : 1 }}>
      {message && <div className="msg ok">{message}</div>}
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap', alignItems: 'flex-start' }}>
        <div>
          <p style={{ fontSize: '1.4rem', fontFamily: 'Anton, sans-serif', textTransform: 'uppercase' }}>
            {m.is_active ? (visible ? '🟢 En ligne' : '🟡 Active, hors période') : '⚫ Roue actuellement hors ligne'}
          </p>
          <p style={{ color: '#6b6560', marginTop: '.3rem' }}>
            Du {fmt(m.start_date)} au {fmt(m.end_date)}
            {m.is_active && !visible && ' · elle apparaîtra automatiquement sur l’accueil pendant cette période.'}
            {!m.is_active && ' · aucune donnée n’est supprimée par la désactivation.'}
          </p>
        </div>
        <div style={{ display: 'flex', gap: '.6rem', flexWrap: 'wrap' }}>
          {m.is_active ? (
            <button className="btn btn-w btn-sm" onClick={() => setConfirm(true)}>Désactiver la roue</button>
          ) : (
            <button className="btn btn-y btn-sm" onClick={() => basculer(true)}>Activer la roue</button>
          )}
          <Link className="btn btn-k btn-sm" href="/#roue-rentree" target="_blank">↗ Voir l&apos;accueil</Link>
        </div>
      </div>

      <div className="kpi" style={{ marginTop: '1.4rem', marginBottom: '1.2rem' }}>
        <div><b>{n(stats.participations)}</b><span>participations</span></div>
        <div><b>{n(stats.joueurs_uniques)}</b><span>joueurs uniques</span></div>
        <div><b>{n(stats.gagnants)}</b><span>gagnants</span></div>
        <div><b>{n(stats.perdants)}</b><span>perdants</span></div>
        <div><b>{n(stats.lots_disponibles)}</b><span>lots encore disponibles</span></div>
      </div>

      <div style={{ display: 'flex', gap: '.5rem', flexWrap: 'wrap' }}>
        {ONGLETS.map((o) => <Link key={o.k} href={`/admin/roue?onglet=${o.k}`} className={`btn btn-sm ${onglet === o.k ? 'btn-k' : 'btn-w'}`}>{o.l}</Link>)}
      </div>

      {confirm && (
        <div className="modal-fond" onClick={() => setConfirm(false)} style={{ position: 'fixed', inset: 0, zIndex: 90, background: 'rgba(20,16,20,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '1rem' }}>
          <div className="panel" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 440, margin: 0 }}>
            <h2>Désactiver la roue ?</h2>
            <p>Voulez-vous vraiment retirer la Roue de la Rentrée de la page d&apos;accueil ?</p>
            <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.5rem' }}>Les participations, gagnants, lots et statistiques sont conservés.</p>
            <div style={{ display: 'flex', gap: '.6rem', marginTop: '1.2rem', justifyContent: 'flex-end' }}>
              <button className="btn btn-w btn-sm" onClick={() => setConfirm(false)}>Annuler</button>
              <button className="btn btn-k btn-sm" onClick={() => basculer(false)}>Désactiver</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
