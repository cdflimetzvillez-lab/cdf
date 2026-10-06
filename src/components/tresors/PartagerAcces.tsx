'use client';
import { useEffect, useState } from 'react';

/**
 * « Jouer sur plusieurs téléphones » : le responsable envoie le lien d'accès du compte à son groupe
 * (partage natif du téléphone quand il existe, sinon SMS, WhatsApp, e-mail ou copie du lien).
 * Chacun ouvre le lien sur son téléphone, puis choisit son prénom en haut de « Mon aventure ».
 */
export default function PartagerAcces({ lien, titre }: { lien: string; titre: string }) {
  const [partageNatif, setPartageNatif] = useState(false);
  const [copie, setCopie] = useState(false);
  const [lienVisible, setLienVisible] = useState(false);

  // Le partage natif n'existe que dans certains navigateurs : on ne montre le bouton que s'il fonctionne.
  useEffect(() => { setPartageNatif(typeof navigator.share === 'function'); }, []);

  const invitation = `Rejoins-nous pour ${titre} ! Ouvre ce lien sur ton téléphone, puis choisis ton prénom en haut de l'écran :`;
  const message = encodeURIComponent(`${invitation} ${lien}`);

  async function partager() {
    try { await navigator.share({ title: titre, text: invitation, url: lien }); } catch { /* partage annulé */ }
  }

  async function copier() {
    try {
      await navigator.clipboard.writeText(lien);
      setCopie(true);
      setTimeout(() => setCopie(false), 2500);
    } catch {
      // Presse-papiers indisponible : on affiche le lien pour le copier à la main.
      setLienVisible(true);
    }
  }

  return (
    <section className="tdn-carte tdn-partage">
      <h2>Jouer sur plusieurs téléphones</h2>
      <p>Envoyez ce lien aux personnes de votre groupe. Chacun l&apos;ouvre sur son téléphone, puis choisit son prénom en haut de l&apos;écran.</p>
      {partageNatif && <button type="button" className="tdn-btn tdn-btn-or tdn-btn-large" onClick={partager}>Partager le lien</button>}
      <div className="tdn-partage-canaux">
        <a className="tdn-btn tdn-btn-ghost" href={`sms:?&body=${message}`}>SMS</a>
        <a className="tdn-btn tdn-btn-ghost" href={`https://wa.me/?text=${message}`} target="_blank" rel="noopener noreferrer">WhatsApp</a>
        <a className="tdn-btn tdn-btn-ghost" href={`mailto:?subject=${encodeURIComponent(titre)}&body=${message}`}>E-mail</a>
        <button type="button" className="tdn-btn tdn-btn-ghost" onClick={copier}>{copie ? 'Lien copié ✓' : 'Copier le lien'}</button>
      </div>
      {lienVisible && <input className="tdn-partage-lien" readOnly value={lien} aria-label="Lien d'accès" onFocus={(e) => e.currentTarget.select()} />}
      <p className="tdn-muted tdn-mini">Ce lien ouvre tout le compte, clés comprises : ne l&apos;envoyez qu&apos;aux personnes de votre groupe.</p>
    </section>
  );
}
