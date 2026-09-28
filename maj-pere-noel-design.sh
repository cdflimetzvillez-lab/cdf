#!/usr/bin/env bash
# Mise à jour : design féerique du Père Noël (accueil avec vidéo démo, lettre et certificat ornés).
# À exécuter à la racine du projet :  bash maj-pere-noel-design.sh
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
mkdir -p 'src/app/pere-noel'
cat > 'src/app/pere-noel/pere-noel.css' <<'EOF_PN_FICHIER'
/* =========================================================
   LE PÈRE NOËL TE RÉPOND — feuille dédiée, préfixe .pn
   Nuit étoilée, or scintillant, papier ancien. Mobile-first.
   ========================================================= */
@import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,500;0,600;0,700;1,500;1,600&family=Great+Vibes&display=swap');

.pn{
  --pn-nuit:#0B1633; --pn-nuit2:#142451; --pn-nuit3:#1E3370;
  --pn-rouge:#B8322E; --pn-rouge2:#8F2420;
  --pn-or:#E7C46A; --pn-or2:#C99A3B; --pn-or3:#F6E4A8;
  --pn-papier:#FBF5E6; --pn-papier2:#F0E4C6; --pn-encre:#2A2116; --pn-encre2:#6B5E4C;
  --pn-neige:#fff; --pn-vert:#2F6B4A; --pn-texte:#EFE8D6; --pn-muted:#A9B5D6;
  --pn-serif:'Cormorant Garamond',Georgia,'Times New Roman',serif;
  --pn-sans:"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  --pn-lueur:0 0 0 1px rgba(231,196,106,.35), 0 10px 40px rgba(0,0,0,.45), 0 0 60px rgba(231,196,106,.12);
  position:relative; min-height:100vh; overflow-x:hidden;
  color:var(--pn-texte); font-family:var(--pn-sans); line-height:1.5; -webkit-font-smoothing:antialiased;
  background:
    radial-gradient(ellipse 120% 60% at 50% -10%, #2A3F7A 0%, transparent 60%),
    radial-gradient(ellipse 80% 40% at 50% 100%, #1A2C5E 0%, transparent 70%),
    linear-gradient(180deg,#0B1633 0%,#0E1C42 55%,#0B1633 100%);
}
.pn *{box-sizing:border-box}
.pn :where(h1,h2,h3){font-family:var(--pn-serif);font-weight:600;text-transform:none;letter-spacing:.01em;line-height:1.1;}
.pn :where(section,footer){padding:0;background:transparent;color:inherit;display:block;}
.pn a{color:inherit}
.pn button{font-family:inherit}

/* ---------- ciel : étoiles + neige (pur CSS, aucune image) ---------- */
.pn-ciel{position:fixed;inset:0;pointer-events:none;z-index:0}
.pn-ciel .etoiles{position:absolute;inset:0;opacity:.9;
  background-image:
    radial-gradient(1.2px 1.2px at 8% 12%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 22% 30%,#fff 60%,transparent 61%),
    radial-gradient(1.6px 1.6px at 36% 8%,#F6E4A8 60%,transparent 61%),
    radial-gradient(1px 1px at 48% 22%,#fff 60%,transparent 61%),
    radial-gradient(1.4px 1.4px at 62% 14%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 74% 34%,#F6E4A8 60%,transparent 61%),
    radial-gradient(1.6px 1.6px at 88% 10%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 14% 58%,#fff 60%,transparent 61%),
    radial-gradient(1.3px 1.3px at 30% 74%,#F6E4A8 60%,transparent 61%),
    radial-gradient(1px 1px at 56% 62%,#fff 60%,transparent 61%),
    radial-gradient(1.5px 1.5px at 70% 80%,#fff 60%,transparent 61%),
    radial-gradient(1px 1px at 92% 56%,#fff 60%,transparent 61%),
    radial-gradient(1.2px 1.2px at 40% 92%,#F6E4A8 60%,transparent 61%),
    radial-gradient(1px 1px at 82% 90%,#fff 60%,transparent 61%);
  animation:pn-scintille 4s ease-in-out infinite alternate}
@keyframes pn-scintille{from{opacity:.5}to{opacity:1}}
.pn-ciel .neige i{position:absolute;top:-12px;width:5px;height:5px;border-radius:50%;background:#fff;opacity:.7;
  box-shadow:0 0 6px rgba(255,255,255,.8);animation:pn-chute linear infinite}
@keyframes pn-chute{to{transform:translateY(110vh) translateX(22px)}}
.pn > *:not(.pn-ciel){position:relative;z-index:1}

/* ---------- en-tête / page ---------- */
.pn-head{display:flex;justify-content:space-between;align-items:center;padding:16px 18px 6px;font-size:12px;max-width:560px;margin:0 auto}
.pn-head .logo{font-family:var(--pn-serif);font-size:18px;font-weight:600;color:var(--pn-or);text-decoration:none;letter-spacing:.02em;text-shadow:0 0 18px rgba(231,196,106,.35)}
.pn-head .cdf{color:var(--pn-muted);text-decoration:none}
.pn-page{max-width:560px;margin:0 auto;padding:12px 18px 60px}
.pn-titre{font-size:34px;margin:18px 0 10px;font-weight:600;
  background:linear-gradient(180deg,#FFF6D6 0%,var(--pn-or) 55%,var(--pn-or2) 100%);-webkit-background-clip:text;background-clip:text;color:transparent;
  filter:drop-shadow(0 2px 12px rgba(231,196,106,.25))}
.pn-sur{font-family:var(--pn-sans);font-size:11px;letter-spacing:.22em;text-transform:uppercase;color:var(--pn-or);text-align:center;margin:0 0 6px}
.pn-ornement{display:flex;align-items:center;gap:10px;justify-content:center;color:var(--pn-or);margin:10px 0;font-size:14px}
.pn-ornement:before,.pn-ornement:after{content:"";height:1px;width:56px;background:linear-gradient(90deg,transparent,var(--pn-or));}
.pn-ornement:after{background:linear-gradient(90deg,var(--pn-or),transparent)}
.pn-l{color:var(--pn-encre2);font-size:14px;margin:0 0 12px}
.pn-l.clair{color:#C9D3EC;font-size:15px;line-height:1.6}
.pn-mini{font-size:12px}.pn-muted{color:var(--pn-muted)}
.pn-centre{text-align:center}

/* ---------- cartes ---------- */
.pn-carte{background:linear-gradient(180deg,#FFFBF0 0%,var(--pn-papier) 100%);color:var(--pn-encre);border-radius:22px;padding:24px 20px;margin:14px 0;
  border:1px solid rgba(201,154,59,.45);box-shadow:var(--pn-lueur);position:relative}
.pn-carte:before{content:"";position:absolute;inset:6px;border:1px solid rgba(201,154,59,.35);border-radius:17px;pointer-events:none}
.pn-carte h2{font-size:24px;margin:0 0 6px;color:var(--pn-nuit)}
.pn-cardn{background:linear-gradient(180deg,rgba(30,51,112,.85),rgba(20,36,81,.85));border:1px solid rgba(231,196,106,.35);border-radius:14px;padding:14px 16px;margin-top:12px;font-size:14px;box-shadow:0 8px 30px rgba(0,0,0,.35)}
.pn-cardn b{color:var(--pn-or3);font-family:var(--pn-serif);font-size:18px;font-weight:600}
.pn-cardn small{display:block;color:#C9D3EC;font-size:12.5px;margin-top:3px}
.pn-avis{border-left:3px solid var(--pn-or);padding:6px 12px;color:#C9D3EC;margin-top:16px;font-style:italic;font-family:var(--pn-serif);font-size:16px}
.pn-avis b{font-style:normal;color:var(--pn-or3)}

/* ---------- boutons ---------- */
.pn-btn{display:block;width:100%;text-align:center;border:0;border-radius:14px;padding:15px 16px;font-size:17px;font-family:var(--pn-serif);font-weight:600;letter-spacing:.02em;margin-top:14px;text-decoration:none;cursor:pointer;position:relative;overflow:hidden;
  background:linear-gradient(180deg,#D24540,var(--pn-rouge) 60%,var(--pn-rouge2));color:#fff;box-shadow:0 8px 24px rgba(184,50,46,.35),inset 0 1px 0 rgba(255,255,255,.25)}
.pn-btn:disabled{opacity:.5;cursor:not-allowed}
.pn-btn.or{background:linear-gradient(180deg,#FFF0BF,var(--pn-or) 55%,var(--pn-or2));color:var(--pn-encre);box-shadow:0 8px 28px rgba(231,196,106,.35),inset 0 1px 0 rgba(255,255,255,.6)}
.pn-btn.or:after{content:"";position:absolute;top:0;left:-60%;width:40%;height:100%;background:linear-gradient(120deg,transparent,rgba(255,255,255,.55),transparent);transform:skewX(-20deg);animation:pn-brillance 3.5s ease-in-out infinite}
@keyframes pn-brillance{0%,60%{left:-60%}100%{left:130%}}
.pn-btn.sec{background:transparent;color:var(--pn-rouge);border:1.5px solid var(--pn-rouge);box-shadow:none}
.pn-btn.vert{background:linear-gradient(180deg,#3E8A61,var(--pn-vert));box-shadow:0 8px 24px rgba(47,107,74,.35)}
.pn-btn.ghost{background:transparent;color:var(--pn-or3);border:1.5px solid rgba(231,196,106,.5);box-shadow:none}
.pn-btn.disabled{opacity:.45;pointer-events:none}
.pn-lien{background:none;border:0;color:var(--pn-encre2);text-decoration:underline;font-size:13px;margin-top:10px;cursor:pointer;display:block;width:100%;text-align:center}

/* ---------- formulaire ---------- */
.pn-champ{margin-top:12px}
.pn-champ label{display:block;font-size:13px;color:var(--pn-encre2);margin:0 0 5px}
.pn-champ input,.pn-champ textarea,.pn-champ select{width:100%;border:1.5px solid #D9CBA6;background:#fff;border-radius:10px;padding:11px 12px;font-size:16px;font-family:inherit;color:var(--pn-encre)}
.pn-champ input:focus,.pn-champ textarea:focus,.pn-champ select:focus{outline:none;border-color:var(--pn-or2);box-shadow:0 0 0 3px rgba(231,196,106,.35)}
.pn-champ textarea{min-height:120px;resize:vertical}
.pn-row{display:flex;gap:10px}.pn-row>*{flex:1}
.pn-steps{display:flex;gap:6px;margin:6px 0 4px}
.pn-steps i{flex:1;height:5px;border-radius:3px;background:rgba(255,255,255,.18)}
.pn-steps i.on{background:linear-gradient(90deg,var(--pn-or2),var(--pn-or3));box-shadow:0 0 10px rgba(231,196,106,.6)}
.pn-stepname{font-size:12px;color:var(--pn-muted);margin-bottom:6px}
.pn-opts{display:flex;gap:6px;margin-top:6px}
.pn-opts label{flex:1;text-align:center;border:1.5px solid #D9CBA6;background:#fff;border-radius:10px;padding:10px 4px;font-size:12px;cursor:pointer;line-height:1.25;color:var(--pn-encre)}
.pn-opts label b{display:block;font-size:22px;font-family:var(--pn-serif);font-weight:600}
.pn-opts label.on{border-color:var(--pn-or2);background:#FFF3CF;color:var(--pn-rouge2);box-shadow:0 0 0 2px rgba(231,196,106,.4)}
.pn-opts input,.pn-chips input{position:absolute;opacity:0;width:0;height:0}
.pn-chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:6px}
.pn-chips label{border:1.5px solid #D9CBA6;background:#fff;border-radius:20px;padding:7px 12px;font-size:13px;cursor:pointer;color:var(--pn-encre)}
.pn-chips label.on{background:var(--pn-nuit);color:var(--pn-or3);border-color:var(--pn-nuit)}
.pn-parch{background:#fff;border:1px solid #E2D6B6;border-radius:12px;padding:14px 16px;font-family:var(--pn-serif);font-size:17px;line-height:1.5;color:var(--pn-encre);position:relative;white-space:pre-line}
.pn-recap dt{color:var(--pn-encre2);font-size:12px;margin-top:10px}.pn-recap dd{margin:2px 0 0;font-size:14px}
.pn-prix{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--pn-papier2);font-size:14px}
.pn-prix.total{font-weight:600;font-size:16px;border-bottom:0}
.pn-erreur{background:#FBE9E5;color:var(--pn-rouge2);border-radius:10px;padding:10px 12px;font-size:14px;margin:10px 0}
.pn-ok{width:76px;height:76px;border-radius:50%;background:radial-gradient(circle at 30% 30%,#5CA97D,var(--pn-vert));color:#fff;font-size:36px;display:flex;align-items:center;justify-content:center;margin:20px auto 12px;box-shadow:0 0 0 6px rgba(231,196,106,.25),0 10px 30px rgba(0,0,0,.4)}

/* ---------- étapes / listes ---------- */
.pn-etapes{list-style:none;padding:0;margin:0}
.pn-etapes li{display:flex;gap:12px;align-items:flex-start;padding:10px 0;border-bottom:1px solid rgba(231,196,106,.18);font-size:14.5px;color:#DCE3F5}
.pn-etapes li span:first-child{width:26px;height:26px;border-radius:50%;background:var(--pn-nuit3);border:1px solid rgba(231,196,106,.4);display:inline-flex;align-items:center;justify-content:center;font-size:12px;flex:none;color:var(--pn-or3);font-family:var(--pn-serif);font-weight:600}
.pn-etapes li.ok span:first-child{background:linear-gradient(180deg,var(--pn-or3),var(--pn-or2));color:var(--pn-encre);border-color:transparent}
.pn-etapes li.now span:first-child{background:var(--pn-rouge);color:#fff;border-color:transparent;animation:pn-pulse 1.6s ease-in-out infinite}
@keyframes pn-pulse{0%,100%{box-shadow:0 0 0 0 rgba(184,50,46,.5)}50%{box-shadow:0 0 0 8px rgba(184,50,46,0)}}
.pn-faq details{border-bottom:1px solid rgba(231,196,106,.18);padding:12px 0}
.pn-faq summary{cursor:pointer;font-family:var(--pn-serif);font-size:19px;font-weight:600;color:var(--pn-or3);list-style:none}
.pn-faq summary::-webkit-details-marker{display:none}
.pn-faq summary:before{content:"✦ ";color:var(--pn-or);font-size:13px}
.pn-faq p{font-size:14px;color:#C9D3EC;margin:8px 0 0 22px}
.pn-foot{max-width:560px;margin:0 auto;padding:18px;font-size:12px;color:var(--pn-muted);border-top:1px solid rgba(231,196,106,.18);text-align:center}

/* ---------- vidéos ---------- */
.pn-video{background:#000;border-radius:18px;overflow:hidden;aspect-ratio:9/16;max-height:78vh;margin:0 auto;border:1px solid rgba(231,196,106,.45);box-shadow:var(--pn-lueur)}
.pn-video video{width:100%;height:100%;object-fit:contain;display:block;background:#000}
.pn-demo{position:relative;border-radius:22px;overflow:hidden;aspect-ratio:9/14;background:#050A1A;border:1px solid rgba(231,196,106,.5);box-shadow:var(--pn-lueur);cursor:pointer}
.pn-demo video,.pn-demo img{width:100%;height:100%;object-fit:cover;display:block}
.pn-demo .voile{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;padding:22px;gap:12px;
  background:linear-gradient(180deg,rgba(5,10,26,.05) 40%,rgba(5,10,26,.85) 100%);transition:opacity .4s}
.pn-demo.joue .voile{opacity:0;pointer-events:none}
.pn-demo .play{width:74px;height:74px;border-radius:50%;background:radial-gradient(circle at 35% 35%,#FFF6D6,var(--pn-or) 60%,var(--pn-or2));color:var(--pn-encre);display:flex;align-items:center;justify-content:center;font-size:30px;padding-left:6px;
  box-shadow:0 0 0 8px rgba(231,196,106,.25),0 0 40px rgba(231,196,106,.55);animation:pn-halo 2.4s ease-in-out infinite}
@keyframes pn-halo{0%,100%{box-shadow:0 0 0 8px rgba(231,196,106,.25),0 0 40px rgba(231,196,106,.55)}50%{box-shadow:0 0 0 14px rgba(231,196,106,.12),0 0 60px rgba(231,196,106,.8)}}
.pn-demo .legende{font-family:var(--pn-serif);font-size:19px;font-weight:600;color:var(--pn-or3);text-align:center;text-shadow:0 2px 10px rgba(0,0,0,.6)}
.pn-demo .sous{font-size:12px;color:#C9D3EC;text-align:center}

/* =========================================================
   DOCUMENTS IMPRIMABLES (lettre, certificat)
   ========================================================= */
.pn-doc{min-height:100vh;padding:24px 14px 40px;font-family:var(--pn-serif);color:var(--pn-encre);position:relative;z-index:1}
.pn-doc-feuille{max-width:640px;margin:0 auto;position:relative;padding:14px;
  background:linear-gradient(180deg,#0E1C42,#142451);border-radius:6px;box-shadow:0 30px 80px rgba(0,0,0,.5)}
.pn-doc-cadre{position:relative;border:2px solid var(--pn-or);outline:1px solid rgba(231,196,106,.5);outline-offset:4px;padding:38px 30px 30px;
  background:
    radial-gradient(circle at 12% 8%,rgba(231,196,106,.14),transparent 30%),
    radial-gradient(circle at 88% 92%,rgba(231,196,106,.14),transparent 30%),
    repeating-linear-gradient(0deg,rgba(0,0,0,.015) 0 2px,transparent 2px 4px),
    linear-gradient(180deg,#FFFBEF 0%,#FBF3DD 100%)}
.pn-doc-coin{position:absolute;width:44px;height:44px;color:var(--pn-or2)}
.pn-doc-coin.hg{top:8px;left:8px}.pn-doc-coin.hd{top:8px;right:8px;transform:scaleX(-1)}
.pn-doc-coin.bg{bottom:8px;left:8px;transform:scaleY(-1)}.pn-doc-coin.bd{bottom:8px;right:8px;transform:scale(-1)}
.pn-doc-sur{font-family:var(--pn-sans);font-size:11px;color:var(--pn-encre2);text-align:center;letter-spacing:.24em;text-transform:uppercase}
.pn-doc h1{font-size:40px;text-align:center;margin:10px 0 2px;font-weight:600;color:var(--pn-nuit);line-height:1.05}
.pn-doc .filet{display:flex;align-items:center;justify-content:center;gap:10px;color:var(--pn-or2);margin:8px 0 14px;font-size:14px}
.pn-doc .filet:before,.pn-doc .filet:after{content:"";height:1px;width:70px;background:linear-gradient(90deg,transparent,var(--pn-or2))}
.pn-doc .filet:after{background:linear-gradient(90deg,var(--pn-or2),transparent)}
.pn-doc .prenom{font-family:'Great Vibes',var(--pn-serif);font-size:64px;color:var(--pn-rouge);text-align:center;margin:2px 0 6px;line-height:1.1;text-shadow:0 2px 0 rgba(231,196,106,.35)}
.pn-doc p{font-size:19px;line-height:1.55;margin:0 0 12px}
.pn-doc .mention{font-style:italic;text-align:center;font-size:21px;color:var(--pn-nuit);max-width:44ch;margin:0 auto 14px}
.pn-doc .lettre{white-space:pre-line;font-size:20px;line-height:1.6;margin-top:10px}
.pn-doc .signature{font-family:'Great Vibes',var(--pn-serif);font-size:40px;color:var(--pn-rouge);text-align:right;margin-top:6px;line-height:1}
.pn-doc .bas{display:flex;justify-content:space-between;align-items:flex-end;margin-top:22px;gap:12px}
.pn-doc .date{font-size:15px;color:var(--pn-encre2);line-height:1.4}
.pn-doc .sceau{position:relative;width:96px;height:96px;flex:none;border-radius:50%;transform:rotate(-8deg);
  background:radial-gradient(circle at 35% 30%,#D64B47,var(--pn-rouge) 55%,var(--pn-rouge2));box-shadow:inset 0 0 0 3px rgba(255,255,255,.25),inset 0 0 0 6px var(--pn-rouge2),0 6px 16px rgba(0,0,0,.25);
  color:#FFF3CF;font-family:var(--pn-serif);font-size:10px;text-align:center;display:flex;flex-direction:column;align-items:center;justify-content:center;line-height:1.2;letter-spacing:.06em;text-transform:uppercase}
.pn-doc .sceau b{font-size:22px;line-height:1;margin:2px 0;font-family:var(--pn-serif)}
.pn-doc .etoiles-doc{position:absolute;inset:0;pointer-events:none;opacity:.55;
  background-image:radial-gradient(1.5px 1.5px at 20% 18%,var(--pn-or2) 60%,transparent 61%),radial-gradient(1px 1px at 80% 12%,var(--pn-or2) 60%,transparent 61%),
    radial-gradient(1.5px 1.5px at 90% 40%,var(--pn-or2) 60%,transparent 61%),radial-gradient(1px 1px at 10% 60%,var(--pn-or2) 60%,transparent 61%),
    radial-gradient(1.5px 1.5px at 30% 88%,var(--pn-or2) 60%,transparent 61%),radial-gradient(1px 1px at 70% 84%,var(--pn-or2) 60%,transparent 61%)}
.pn-doc .actions{max-width:640px;margin:18px auto 0;display:flex;gap:10px;font-family:var(--pn-sans)}
.pn-doc .actions a,.pn-doc .actions button{flex:1;text-align:center;padding:13px;border-radius:12px;border:1.5px solid var(--pn-or);font-size:15px;cursor:pointer;text-decoration:none;font-family:var(--pn-serif);font-weight:600}
.pn-doc .actions a{background:transparent;color:var(--pn-or3)}
.pn-doc .actions button{background:linear-gradient(180deg,#FFF0BF,var(--pn-or) 55%,var(--pn-or2));color:var(--pn-encre);border-color:transparent}
@media print{
  .pn{background:#fff!important}
  .pn-ciel,.pn-head,.pn-foot,.pn-doc .actions{display:none!important}
  .pn-doc{padding:0;min-height:0}
  .pn-doc-feuille{background:none;box-shadow:none;padding:0;max-width:none}
  .pn-doc-cadre{page-break-inside:avoid;-webkit-print-color-adjust:exact;print-color-adjust:exact}
  @page{margin:12mm}
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/pere-noel.css"
mkdir -p 'src/app/pere-noel'
cat > 'src/app/pere-noel/layout.tsx' <<'EOF_PN_FICHIER'
import type { Metadata } from 'next';
import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { requireAdmin } from '@/lib/supabase/server';
import Ciel from '@/components/pere-noel/Ciel';
import './pere-noel.css';

export const dynamic = 'force-dynamic';

export async function generateMetadata(): Promise<Metadata> {
  const r = await lireReglagesPn();
  return { title: `${r.titre} · Comité des Fêtes`, description: r.accroche };
}

export default async function PereNoelLayout({ children }: { children: React.ReactNode }) {
  const r = await lireReglagesPn();
  if (!r.module_actif) {
    const { isAdmin } = await requireAdmin();
    if (!isAdmin) {
      return (
        <div className="pn">
          <Ciel />
          <main className="pn-page pn-centre" style={{ paddingTop: '20vh' }}>
            <h1 className="pn-titre">{r.titre}</h1>
            <p className="pn-l clair">Ce service n&apos;est pas disponible pour le moment. Revenez bientôt !</p>
            <Link href="/" className="pn-btn ghost">Retour au site</Link>
          </main>
        </div>
      );
    }
  }
  return (
    <div className="pn">
      <Ciel />
      <div className="pn-head">
        <Link href="/pere-noel" className="logo">✦ {r.titre}</Link>
        <Link href="/" className="cdf">Une action du Comité des Fêtes</Link>
      </div>
      {children}
      <div className="pn-foot">Une action du Comité des Fêtes. Les bénéfices financent les événements de l&apos;année. Aucune donnée d&apos;enfant n&apos;est publiée.</div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/layout.tsx"
mkdir -p 'src/app/pere-noel'
cat > 'src/app/pere-noel/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import { euros } from '@/lib/sumup';
import DemoVideo from '@/components/pere-noel/DemoVideo';

export default async function PageAccueilPn() {
  const r = await lireReglagesPn();

  return (
    <main className="pn-page">
      <p className="pn-sur">Une lettre · une réponse · un souvenir pour toujours</p>
      <h1 className="pn-titre pn-centre" style={{ marginTop: 4 }}>{r.accroche}</h1>
      <div className="pn-ornement">✦</div>

      {r.video_demo_url
        ? <DemoVideo src={r.video_demo_url} poster={r.image_url} />
        : r.image_url
          // eslint-disable-next-line @next/next/no-img-element
          ? <div className="pn-demo" style={{ cursor: 'default' }}><img src={r.image_url} alt="Le Père Noël dans son atelier" /></div>
          : null}

      <p className="pn-l clair pn-centre" style={{ marginTop: 18 }}>
        Pas un message tout fait avec un prénom collé dessus : une vraie réponse à ce que votre enfant a écrit.
        Sa lettre, son doudou, ses fiertés de l&apos;année, un secret que seul le Père Noël pouvait connaître… tout y est.
      </p>

      <div className="pn-cardn pn-centre"><b>{euros(r.prix_centimes)}</b> la vidéo personnalisée<small>Livrée {r.delai_texte}. Lettre écrite du Père Noël et certificat d&apos;enfant sage inclus, à imprimer.</small></div>

      {r.commandes_ouvertes
        ? <Link href="/pere-noel/commander" className="pn-btn or">✦ Écrire au Père Noël</Link>
        : <div className="pn-cardn pn-centre">Les commandes ouvriront bientôt.</div>}

      <div className="pn-ornement" style={{ marginTop: 26 }}>Comment ça marche</div>
      <ul className="pn-etapes">
        <li className="ok"><span>1</span><div>Vous racontez : prénom, sa lettre, ses fiertés, un petit secret. Cinq minutes, avec lui ou en cachette.</div></li>
        <li className="ok"><span>2</span><div>Le Père Noël lui répond en vidéo, avec ses mots à lui, en prononçant son prénom.</div></li>
        <li className="ok"><span>3</span><div>Vous téléchargez la vidéo, imprimez la lettre et le certificat. Magie garantie le soir de Noël.</div></li>
      </ul>

      <div className="pn-avis"><b>Un conseil :</b> ne montrez pas la vidéo tout de suite. Le soir, dans le noir, sur la télé du salon, l&apos;effet est décuplé.</div>

      <div className="pn-faq" style={{ marginTop: 22 }}>
        <details><summary>Le Père Noël dit vraiment le prénom ?</summary><p>Oui. Vous pouvez même indiquer comment il se prononce pour éviter toute erreur.</p></details>
        <details><summary>Combien de temps dure la vidéo ?</summary><p>Environ une minute quinze, en format vertical plein écran, idéale sur un téléphone ou la télé du salon.</p></details>
        <details><summary>Et si quelque chose ne va pas ?</summary><p>Un détail inexact, un prénom mal prononcé : écrivez-nous depuis votre espace, nous refaisons la vidéo.</p></details>
        <details><summary>Où va l&apos;argent ?</summary><p>C&apos;est une action du Comité des Fêtes : les bénéfices financent les événements de l&apos;année.</p></details>
      </div>
    </main>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/page.tsx"
mkdir -p 'src/app/pere-noel/ma-video/[token]/certificat'
cat > 'src/app/pere-noel/ma-video/[token]/certificat/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';
import { Coin, Sceau } from '@/components/pere-noel/Ornement';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

export default async function PageCertificat({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);
  const annee = d.getFullYear();
  const mention = c.certificat_mention || `pour son année ${annee}, remarquée depuis le ciel pour sa gentillesse et son courage.`;
  const fem = c.genre === 'fille';

  return (
    <div className="pn-doc">
      <div className="pn-doc-feuille">
        <div className="pn-doc-cadre">
          <div className="etoiles-doc" />
          <Coin pos="hg" /><Coin pos="hd" /><Coin pos="bg" /><Coin pos="bd" />
          <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
          <h1>Certificat d&apos;enfant sage</h1>
          <div className="filet">✦ ✦ ✦</div>
          <p style={{ textAlign: 'center', margin: 0, fontStyle: 'italic' }}>décerné à</p>
          <div className="prenom">{c.enfant_prenom}</div>
          <p className="mention">{mention}</p>
          <p style={{ textAlign: 'center', fontSize: 16, color: '#6B5E4C', margin: '0 auto', maxWidth: '46ch' }}>
            Le Père Noël atteste que {c.enfant_prenom} est inscrit{fem ? 'e' : ''} sur la grande liste des enfants sages de l&apos;année {annee}, et qu&apos;{fem ? 'elle' : 'il'} peut en être fi{fem ? 'ère' : 'er'}.
          </p>
          <div className="bas">
            <div className="date">Fait au Pôle Nord,<br />le {d.getDate()} {MOIS[d.getMonth()]} {annee}<div className="signature" style={{ textAlign: 'left', marginTop: 8 }}>Le Père Noël</div></div>
            <Sceau />
          </div>
        </div>
      </div>
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/ma-video/[token]/certificat/page.tsx"
mkdir -p 'src/app/pere-noel/ma-video/[token]/lettre'
cat > 'src/app/pere-noel/ma-video/[token]/lettre/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { commandeParToken } from '@/lib/pere-noel/db';
import BoutonImprimer from '@/components/pere-noel/BoutonImprimer';
import { Coin, Sceau } from '@/components/pere-noel/Ornement';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

export default async function PageLettre({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const c = await commandeParToken(token);
  if (!c || !c.lettre_reponse) notFound();
  const d = new Date(c.livre_le ?? c.paye_le ?? c.created_at);
  // La signature « Le Père Noël » est rendue à part, en écriture manuscrite.
  const corps = c.lettre_reponse!.replace(/\n*\s*Le Père Noël\s*$/i, '').trim();

  return (
    <div className="pn-doc">
      <div className="pn-doc-feuille">
        <div className="pn-doc-cadre">
          <div className="etoiles-doc" />
          <Coin pos="hg" /><Coin pos="hd" /><Coin pos="bg" /><Coin pos="bd" />
          <div className="pn-doc-sur">Bureau du Père Noël · Pôle Nord</div>
          <div className="filet">✦</div>
          <div className="date" style={{ textAlign: 'right' }}>Pôle Nord, le {d.getDate()} {MOIS[d.getMonth()]} {d.getFullYear()}</div>
          <p className="lettre">{corps}</p>
          <div className="bas">
            <div className="signature">Le Père Noël</div>
            <Sceau />
          </div>
        </div>
      </div>
      <div className="actions">
        <Link href={`/pere-noel/ma-video/${c.token}`}>Retour</Link>
        <BoutonImprimer />
      </div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel/ma-video/[token]/lettre/page.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/Ciel.tsx' <<'EOF_PN_FICHIER'
/** Ciel étoilé et neige, en pur CSS. Rendu côté serveur, aucune image. */
export default function Ciel() {
  const flocons = Array.from({ length: 26 }, (_, i) => ({
    left: (i * 37) % 100, duree: 9 + (i % 7) * 1.7, delai: -((i * 1.3) % 12), taille: 3 + (i % 4),
  }));
  return (
    <div className="pn-ciel" aria-hidden="true">
      <div className="etoiles" />
      <div className="neige">
        {flocons.map((f, i) => (
          <i key={i} style={{ left: `${f.left}%`, width: f.taille, height: f.taille, animationDuration: `${f.duree}s`, animationDelay: `${f.delai}s`, opacity: .35 + (i % 4) * .15 }} />
        ))}
      </div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/Ciel.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/DemoVideo.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useRef, useState } from 'react';

export default function DemoVideo({ src, poster }: { src: string; poster?: string | null }) {
  const ref = useRef<HTMLVideoElement>(null);
  const [joue, setJoue] = useState(false);
  const lancer = () => { const v = ref.current; if (!v) return; if (v.paused) { v.play(); setJoue(true); } else { v.pause(); setJoue(false); } };
  return (
    <div className={`pn-demo${joue ? ' joue' : ''}`} onClick={lancer} role="button" aria-label="Lire la vidéo de démonstration">
      <video ref={ref} src={src} poster={poster ?? undefined} playsInline preload="metadata" controls={joue} onEnded={() => setJoue(false)} onPause={() => setJoue(false)} onPlay={() => setJoue(true)} />
      <div className="voile">
        <div className="play">▶</div>
        <div className="legende">Écoute le Père Noël répondre à Léa</div>
        <div className="sous">Un exemple de vidéo, telle que la recevra ton enfant</div>
      </div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/DemoVideo.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/Ornement.tsx' <<'EOF_PN_FICHIER'
/** Coin doré décoratif pour les documents imprimables. */
export function Coin({ pos }: { pos: 'hg' | 'hd' | 'bg' | 'bd' }) {
  return (
    <svg className={`pn-doc-coin ${pos}`} viewBox="0 0 44 44" fill="none" stroke="currentColor" strokeWidth="1.4" aria-hidden="true">
      <path d="M2 42V10Q2 2 10 2H42" />
      <path d="M8 42V14Q8 8 14 8H42" opacity=".55" />
      <path d="M2 2l8 8M6 2q6 3 9 9M2 6q3 6 9 9" strokeLinecap="round" />
      <circle cx="16" cy="16" r="2" fill="currentColor" stroke="none" />
    </svg>
  );
}
export function Sceau() {
  return <div className="sceau"><span>Bureau du</span><b>★</b><span>Père Noël</span><span style={{ fontSize: 8, opacity: .8 }}>Pôle Nord</span></div>;
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/Ornement.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/FormReglagesPn.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState } from 'react';
import { majReglagesPn, type Etat } from '@/app/pere-noel-actions';
import ChampImage from '@/components/ChampImage';
import type { ReglagesPn } from '@/lib/pere-noel/types';

type Cles = { anthropic: boolean; elevenlabs: boolean; heygen: boolean; voixEnv: string };

export default function FormReglagesPn({ r, cles }: { r: ReglagesPn; cles: Cles }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(majReglagesPn, null);
  const ok = (b: boolean) => <span className={`pill ${b ? 'done' : 'off'}`}>{b ? 'présente' : 'absente'}</span>;
  return (
    <form action={action}>
      {etat?.ok && <div className="msg ok">{etat.ok}</div>}
      {etat?.erreur && <div className="msg ko">{etat.erreur}</div>}

      <div className="panel">
        <h2>Clés API (variables d’environnement Vercel)</h2>
        <p style={{ fontSize: '.9rem' }}>ANTHROPIC_API_KEY {ok(cles.anthropic)} · ELEVENLABS_API_KEY {ok(cles.elevenlabs)} · HEYGEN_API_KEY {ok(cles.heygen)}</p>
        <p style={{ color: '#6b6560', fontSize: '.85rem', marginTop: '.4rem' }}>Les clés ne se saisissent pas ici : ajoutez-les dans Vercel puis redéployez.</p>
      </div>

      <div className="panel">
        <h2>Textes et prix</h2>
        <div className="field"><label htmlFor="titre">Titre</label><input id="titre" name="titre" defaultValue={r.titre} /></div>
        <div className="field"><label htmlFor="accroche">Accroche (page d’accueil)</label><input id="accroche" name="accroche" defaultValue={r.accroche} /></div>
        <div className="row2">
          <div className="field"><label htmlFor="prix">Prix (€)</label><input id="prix" name="prix" type="number" step="0.1" min={0} defaultValue={r.prix_centimes / 100} /></div>
          <div className="field"><label htmlFor="delai_texte">Délai annoncé</label><input id="delai_texte" name="delai_texte" defaultValue={r.delai_texte} /></div>
        </div>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="commandes_ouvertes" defaultChecked={r.commandes_ouvertes} style={{ width: 'auto' }} /> Commandes ouvertes au public</label>
      </div>

      <div className="panel">
        <h2>Génération</h2>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="generation_auto" defaultChecked={r.generation_auto} style={{ width: 'auto' }} /> Lancer la génération automatiquement dès le paiement</label>
        <label className="field" style={{ display: 'flex', gap: '.6rem', alignItems: 'center' }}><input type="checkbox" name="relecture_script" defaultChecked={r.relecture_script} style={{ width: 'auto' }} /> Relire et valider le script avant l’audio et la vidéo (conseillé au début)</label>
        <p style={{ color: '#6b6560', fontSize: '.85rem' }}>Génération manuelle = rien ne part chez HeyGen tant que vous n’avez pas cliqué « Générer » sur la commande. Utile tant que le compte HeyGen n’a pas de crédits.</p>
        <div className="field"><label htmlFor="duree_cible_sec">Durée cible de la vidéo (secondes, 30 à 120)</label><input id="duree_cible_sec" name="duree_cible_sec" type="number" min={30} max={120} defaultValue={r.duree_cible_sec} /></div>
        <div className="field"><label htmlFor="consignes_script">Consignes supplémentaires pour l’écriture du script (facultatif)</label>
          <textarea id="consignes_script" name="consignes_script" rows={3} defaultValue={r.consignes_script} placeholder="Ex. : mentionner que le Père Noël passera aussi par le village le 20 décembre." /></div>
      </div>

      <div className="panel">
        <h2>Le Père Noël (image)</h2>
        <ChampImage name="image_url" label="Portrait du Père Noël, format vertical 9:16, bouche bien visible" valeurInitiale={r.image_url} dossier="pere-noel" aide="C’est cette image qui est animée par HeyGen pour chaque vidéo." />
        <div className="field"><label htmlFor="video_demo_url">Vidéo de démonstration (URL du MP4, affichée sur la page d’accueil)</label>
          <input id="video_demo_url" name="video_demo_url" defaultValue={r.video_demo_url ?? ''} placeholder="https://…vercel-storage.com/pere-noel/demo.mp4" />
          <p style={{ color: '#6b6560', fontSize: '.8rem', marginTop: '.3rem' }}>Déposez le MP4 dans Vercel → Storage → cdf-blob → Manage Blobs → Upload, puis collez ici l’URL du fichier. L’image ci-dessus sert d’affiche avant lecture.</p></div>
        <div className="field"><label htmlFor="expressivite">Expressivité HeyGen</label>
          <select id="expressivite" name="expressivite" defaultValue={r.expressivite}><option value="low">Faible (sobre)</option><option value="medium">Moyenne (conseillé)</option><option value="high">Forte (rires, gestes, risque d’artefacts)</option></select></div>
        <div className="field"><label htmlFor="motion_prompt">Consigne de mouvement (HeyGen)</label><textarea id="motion_prompt" name="motion_prompt" rows={2} defaultValue={r.motion_prompt} /></div>
      </div>

      <div className="panel">
        <h2>La voix (ElevenLabs)</h2>
        <div className="field"><label htmlFor="voice_id">Voice ID</label><input id="voice_id" name="voice_id" defaultValue={r.voice_id ?? ''} placeholder={cles.voixEnv ? `Par défaut : ${cles.voixEnv} (variable ELEVENLABS_VOICE_ID)` : 'Ex. : MDLAMJ0jxkpYkjXbmG4t'} /></div>
        <div className="row2">
          <div className="field"><label htmlFor="modele_voix">Modèle</label>
            <select id="modele_voix" name="modele_voix" defaultValue={r.modele_voix}><option value="eleven_multilingual_v2">Multilingual v2 (stable)</option><option value="eleven_v3">Eleven v3 (plus expressif)</option><option value="eleven_turbo_v2_5">Turbo v2.5 (rapide, moins cher)</option></select></div>
          <div className="field"><label htmlFor="vitesse">Vitesse (0,7 à 1,2)</label><input id="vitesse" name="vitesse" type="number" step="0.01" min={0.7} max={1.2} defaultValue={r.vitesse} /></div>
        </div>
        <div className="row3">
          <div className="field"><label htmlFor="stabilite">Stabilité (0 à 1)</label><input id="stabilite" name="stabilite" type="number" step="0.05" min={0} max={1} defaultValue={r.stabilite} /></div>
          <div className="field"><label htmlFor="similarite">Similarité (0 à 1)</label><input id="similarite" name="similarite" type="number" step="0.05" min={0} max={1} defaultValue={r.similarite} /></div>
          <div className="field"><label htmlFor="style_voix">Style (0 à 1)</label><input id="style_voix" name="style_voix" type="number" step="0.05" min={0} max={1} defaultValue={r.style_voix} /></div>
        </div>
      </div>

      <button className="btn btn-y" type="submit" disabled={pending}>{pending ? 'Enregistrement…' : 'Enregistrer les réglages'}</button>
    </form>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/FormReglagesPn.tsx"
mkdir -p 'src/lib/pere-noel'
cat > 'src/lib/pere-noel/types.ts' <<'EOF_PN_FICHIER'
export type Sagesse = 'presque' | 'tres_sage' | 'le_plus_sage';
export type TonSecret = 'rigolo' | 'tendre' | 'serieux';
export type StatutPaiement = 'en_attente' | 'payee' | 'echouee' | 'expiree';
export type StatutGeneration = 'a_faire' | 'relecture' | 'audio' | 'video' | 'terminee' | 'erreur';

export interface ReglagesPn {
  id: 1;
  module_actif: boolean;
  commandes_ouvertes: boolean;
  titre: string;
  accroche: string;
  prix_centimes: number;
  delai_texte: string;
  generation_auto: boolean;
  relecture_script: boolean;
  image_url: string | null;
  video_demo_url: string | null;
  voice_id: string | null;
  modele_voix: string;
  stabilite: number;
  similarite: number;
  style_voix: number;
  vitesse: number;
  expressivite: 'low' | 'medium' | 'high';
  motion_prompt: string;
  duree_cible_sec: number;
  consignes_script: string;
}

export interface CommandePn {
  id: string;
  created_at: string;
  reference: string;
  token: string;
  test: boolean;
  parent_prenom: string;
  email: string;
  enfant_prenom: string;
  prononciation: string | null;
  age: number | null;
  genre: 'fille' | 'garcon' | null;
  sagesse: Sagesse;
  lettre: string | null;
  cadeaux: string | null;
  fierte: string | null;
  passion: string | null;
  effort: string | null;
  salut: string | null;
  secret: string | null;
  ton_secret: TonSecret;
  montant_centimes: number;
  checkout_id: string | null;
  statut: StatutPaiement;
  transaction_code: string | null;
  paye_le: string | null;
  gen_statut: StatutGeneration;
  script: string | null;
  lettre_reponse: string | null;
  certificat_mention: string | null;
  audio_url: string | null;
  heygen_video_id: string | null;
  video_url: string | null;
  duree_sec: number | null;
  erreur: string | null;
  livre_le: string | null;
  email_envoye: boolean;
}

export interface StatsPn {
  commandes: number;
  ca_centimes: number;
  a_generer: number;
  a_relire: number;
  en_cours: number;
  livrees: number;
  en_erreur: number;
  secondes_video: number;
}

export const LIBELLE_SAGESSE: Record<Sagesse, string> = {
  presque: 'presque sage',
  tres_sage: 'très sage',
  le_plus_sage: 'le plus sage du monde',
};

export const LIBELLE_GEN: Record<StatutGeneration, string> = {
  a_faire: 'À générer',
  relecture: 'Script à relire',
  audio: 'Audio en cours',
  video: 'Vidéo en cours',
  terminee: 'Livrée',
  erreur: 'Erreur',
};

/** Coût HeyGen Avatar IV : 0,05 $ la seconde. Affiché à titre indicatif. */
export const COUT_HEYGEN_USD_PAR_SEC = 0.05;
EOF_PN_FICHIER
echo "  ✓ src/lib/pere-noel/types.ts"
mkdir -p 'src/app'
cat > 'src/app/pere-noel-actions.ts' <<'EOF_PN_FICHIER'
'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createAdminClient } from '@/lib/supabase/admin';
import { requireAdmin } from '@/lib/supabase/server';
import { creerCheckout, lireCheckout } from '@/lib/sumup';
import { commandeParId, lireReglagesPn, majCommande, referencePn } from '@/lib/pere-noel/db';
import { emailConfirmation, emailVideoPrete } from '@/lib/pere-noel/emails';
import { avancerCommande, traiterFile, verifierVideo } from '@/lib/pere-noel/pipeline';
import type { CommandePn, Sagesse, TonSecret } from '@/lib/pere-noel/types';

export type Etat = { ok?: string; erreur?: string } | null;

const emailValide = (e: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
const txt = (fd: FormData, k: string, max = 1200) => String(fd.get(k) ?? '').trim().slice(0, max) || null;

/* =========================================================
   COMMANDE PUBLIQUE + PAIEMENT SUMUP
   ========================================================= */
export async function commander(_prev: Etat, fd: FormData): Promise<Etat> {
  const r = await lireReglagesPn();
  const { isAdmin } = await requireAdmin();
  const modeTest = fd.get('test') === '1' && isAdmin;
  if (!r.commandes_ouvertes && !modeTest) return { erreur: 'Les commandes ne sont pas ouvertes pour le moment.' };

  const email = String(fd.get('email') ?? '').trim().toLowerCase();
  const enfant = txt(fd, 'enfant_prenom', 40);
  if (!enfant) return { erreur: 'Le prénom de l’enfant est obligatoire.' };
  if (!emailValide(email)) return { erreur: 'Adresse email invalide.' };
  const age = Number(fd.get('age'));
  const sagesse = (['presque', 'tres_sage', 'le_plus_sage'].includes(String(fd.get('sagesse'))) ? String(fd.get('sagesse')) : 'tres_sage') as Sagesse;
  const ton = (['rigolo', 'tendre', 'serieux'].includes(String(fd.get('ton_secret'))) ? String(fd.get('ton_secret')) : 'rigolo') as TonSecret;
  const genreBrut = String(fd.get('genre') ?? '');
  const genre = genreBrut === 'fille' || genreBrut === 'garcon' ? genreBrut : null;
  const lettre = txt(fd, 'lettre', 1500);
  if (!lettre && !txt(fd, 'cadeaux', 300)) return { erreur: 'Écrivez au moins la lettre de l’enfant ou ce qu’il demande.' };

  const db = createAdminClient();
  const reference = referencePn();
  const montant = modeTest ? 0 : r.prix_centimes;
  const { data: cmd, error } = await db.from('pn_commandes').insert({
    reference, test: modeTest,
    parent_prenom: txt(fd, 'parent_prenom', 60) ?? '', email,
    enfant_prenom: enfant, prononciation: txt(fd, 'prononciation', 60),
    age: Number.isFinite(age) && age > 0 && age < 18 ? age : null, genre, sagesse,
    lettre, cadeaux: txt(fd, 'cadeaux', 300), fierte: txt(fd, 'fierte', 300), passion: txt(fd, 'passion', 300),
    effort: txt(fd, 'effort', 200), salut: txt(fd, 'salut', 120), secret: txt(fd, 'secret', 500), ton_secret: ton,
    montant_centimes: montant,
    statut: montant === 0 ? 'payee' : 'en_attente', paye_le: montant === 0 ? new Date().toISOString() : null,
  }).select('*').single();
  if (error || !cmd) { console.error('[pn commander]', error); return { erreur: 'Impossible d’enregistrer la commande.' }; }

  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  if (montant === 0) {
    await emailConfirmation(cmd as CommandePn, r);
    redirect(`/pere-noel/commander/retour?ref=${reference}`);
  }

  let url: string | undefined;
  try {
    const checkout = await creerCheckout({
      reference, montantCentimes: montant,
      description: `${reference} · Vidéo du Père Noël pour ${enfant}`,
      emailClient: email, urlRetour: `${base}/pere-noel/commander/retour?ref=${reference}`,
    });
    await db.from('pn_commandes').update({ checkout_id: checkout.id }).eq('id', cmd.id);
    url = checkout.hosted_checkout_url;
  } catch (e) {
    console.error('[pn commander] SumUp', e);
    await db.from('pn_commandes').update({ statut: 'echouee' }).eq('id', cmd.id);
    return { erreur: 'Le service de paiement est indisponible. Réessayez dans quelques minutes.' };
  }
  if (!url) return { erreur: 'Le paiement n’a pas pu être initialisé.' };
  redirect(url);
}

/** Synchronise une commande avec SumUp (retour de paiement ou webhook). Déclenche l'email et, si activé, la génération. */
export async function synchroniserCommandePn(reference?: string, checkoutId?: string): Promise<CommandePn | null> {
  const db = createAdminClient();
  const req = db.from('pn_commandes').select('*');
  const { data: cmd } = await (reference ? req.eq('reference', reference) : req.eq('checkout_id', checkoutId!)).maybeSingle();
  if (!cmd) return null;
  if (cmd.statut === 'payee' || !cmd.checkout_id) return cmd as CommandePn;

  try {
    const checkout = await lireCheckout(cmd.checkout_id);
    const corr: Record<string, string> = { PAID: 'payee', FAILED: 'echouee', EXPIRED: 'expiree', PENDING: 'en_attente' };
    const statut = corr[checkout.status] ?? 'en_attente';
    if (statut === cmd.statut) return cmd as CommandePn;
    const { data: maj } = await db.from('pn_commandes').update({
      statut,
      transaction_code: checkout.transaction_code ?? checkout.transactions?.[0]?.transaction_code ?? null,
      paye_le: statut === 'payee' ? new Date().toISOString() : null,
    }).eq('id', cmd.id).select('*').single();
    if (statut === 'payee' && maj) {
      const r = await lireReglagesPn();
      await emailConfirmation(maj as CommandePn, r);
      if (r.generation_auto) avancerCommande(maj.id).catch((e) => console.error('[pn auto]', e));
    }
    return (maj ?? cmd) as CommandePn;
  } catch (e) {
    console.error('[synchroniserCommandePn]', e);
    return cmd as CommandePn;
  }
}

/** Depuis l'espace famille : si la vidéo est en cours chez HeyGen, on vérifie à chaque visite. */
export async function rafraichirDepuisEspace(id: string) {
  const c = await commandeParId(id);
  if (c && c.gen_statut === 'video') await verifierVideo(id);
}

/* =========================================================
   ADMIN
   ========================================================= */
async function admin() {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) throw new Error('Accès refusé.');
}
const chemins = () => { revalidatePath('/admin/pere-noel', 'layout'); revalidatePath('/pere-noel', 'layout'); revalidatePath('/'); };

export async function basculerModulePn(actif: boolean) {
  await admin();
  await createAdminClient().from('pn_reglages').update({ module_actif: actif }).eq('id', 1);
  chemins();
}

export async function majReglagesPn(_prev: Etat, fd: FormData): Promise<Etat> {
  await admin();
  const num = (k: string, def: number) => { const v = Number(fd.get(k)); return Number.isFinite(v) ? v : def; };
  const expr = String(fd.get('expressivite') ?? 'medium');
  const { error } = await createAdminClient().from('pn_reglages').update({
    titre: String(fd.get('titre') ?? '').trim() || 'Le Père Noël te répond',
    accroche: String(fd.get('accroche') ?? '').trim(),
    prix_centimes: Math.round(num('prix', 12.9) * 100),
    delai_texte: String(fd.get('delai_texte') ?? '').trim() || 'sous 48 h',
    commandes_ouvertes: fd.get('commandes_ouvertes') === 'on',
    generation_auto: fd.get('generation_auto') === 'on',
    relecture_script: fd.get('relecture_script') === 'on',
    image_url: String(fd.get('image_url') ?? '').trim() || null,
    video_demo_url: String(fd.get('video_demo_url') ?? '').trim() || null,
    voice_id: String(fd.get('voice_id') ?? '').trim() || null,
    modele_voix: String(fd.get('modele_voix') ?? '').trim() || 'eleven_multilingual_v2',
    stabilite: num('stabilite', 0.45), similarite: num('similarite', 0.75), style_voix: num('style_voix', 0.3), vitesse: num('vitesse', 0.92),
    expressivite: ['low', 'medium', 'high'].includes(expr) ? expr : 'medium',
    motion_prompt: String(fd.get('motion_prompt') ?? '').trim(),
    duree_cible_sec: Math.min(120, Math.max(30, Math.round(num('duree_cible_sec', 75)))),
    consignes_script: String(fd.get('consignes_script') ?? '').trim(),
    updated_at: new Date().toISOString(),
  }).eq('id', 1);
  if (error) return { erreur: error.message };
  chemins();
  return { ok: 'Réglages enregistrés.' };
}

/** Lance ou reprend la génération (script, audio, vidéo). */
export async function genererCommande(id: string) {
  await admin();
  await avancerCommande(id);
  chemins();
}

/** Valide (ou modifie) le script puis enchaîne audio et vidéo. */
export async function validerScript(_prev: Etat, fd: FormData): Promise<Etat> {
  await admin();
  const id = String(fd.get('id') ?? '');
  const script = String(fd.get('script') ?? '').trim();
  const lettre = String(fd.get('lettre_reponse') ?? '').trim();
  const mention = String(fd.get('certificat_mention') ?? '').trim();
  if (!id || script.length < 50) return { erreur: 'Script trop court.' };
  await majCommande(id, { script, lettre_reponse: lettre || null, certificat_mention: mention || null, audio_url: null, heygen_video_id: null, video_url: null, gen_statut: 'audio', erreur: null });
  const c = await avancerCommande(id, { ignorerRelecture: true });
  chemins();
  return c.gen_statut === 'erreur' ? { erreur: c.erreur ?? 'Erreur de génération.' } : { ok: 'Script validé, audio et vidéo lancés.' };
}

/** Régénère le script (le précédent est écrasé), retour en relecture. */
export async function regenererScript(id: string) {
  await admin();
  await majCommande(id, { script: null, lettre_reponse: null, certificat_mention: null, audio_url: null, heygen_video_id: null, video_url: null, gen_statut: 'a_faire', erreur: null });
  await avancerCommande(id);
  chemins();
}

/** Repart de zéro côté vidéo en gardant le script (ex. artefact HeyGen). */
export async function refaireVideo(id: string) {
  await admin();
  await majCommande(id, { heygen_video_id: null, video_url: null, duree_sec: null, email_envoye: false, gen_statut: 'audio', erreur: null });
  await avancerCommande(id, { ignorerRelecture: true });
  chemins();
}

export async function verifierCommande(id: string) {
  await admin();
  await verifierVideo(id);
  chemins();
}

export async function verifierToutes() {
  await admin();
  const res = await traiterFile(10);
  chemins();
  return res;
}

export async function renvoyerEmailVideo(id: string) {
  await admin();
  const c = await commandeParId(id);
  if (c?.video_url) { const ok = await emailVideoPrete(c); if (ok) await majCommande(id, { email_envoye: true }); }
  chemins();
}

export async function marquerPayee(id: string) {
  await admin();
  const c = await commandeParId(id);
  if (!c || c.statut === 'payee') return;
  await majCommande(id, { statut: 'payee', paye_le: new Date().toISOString() });
  const r = await lireReglagesPn();
  await emailConfirmation({ ...c, statut: 'payee' }, r);
  chemins();
}

export async function supprimerCommande(id: string) {
  await admin();
  await createAdminClient().from('pn_commandes').delete().eq('id', id);
  chemins();
  redirect('/admin/pere-noel');
}
EOF_PN_FICHIER
echo "  ✓ src/app/pere-noel-actions.ts"
mkdir -p 'supabase'
cat > 'supabase/pere_noel.sql' <<'EOF_PN_FICHIER'
-- =========================================================
-- LE PÈRE NOËL TE RÉPOND — tables du module (préfixe pn_)
-- À exécuter une fois dans l'éditeur SQL de Supabase.
-- Les médias (image du Père Noël, audios, vidéos) vont dans le
-- bucket public « medias » déjà utilisé par le site, dossier pere-noel/.
-- =========================================================

create table if not exists pn_reglages (
  id                 int primary key default 1 check (id = 1),
  module_actif       boolean not null default false,
  commandes_ouvertes boolean not null default false,
  titre              text not null default 'Le Père Noël te répond',
  accroche           text not null default 'Ton enfant écrit au Père Noël. Le Père Noël lui répond en vidéo.',
  prix_centimes      int  not null default 1290,
  delai_texte        text not null default 'sous 48 h',
  generation_auto    boolean not null default false,   -- lancer la génération dès le paiement
  relecture_script   boolean not null default true,    -- l'admin relit le script avant l'audio/vidéo
  image_url          text,                              -- image du Père Noël (portrait 9:16)
  video_demo_url     text,                              -- vidéo de démonstration (page d'accueil)
  voice_id           text,                              -- voix ElevenLabs
  modele_voix        text not null default 'eleven_multilingual_v2',
  stabilite          numeric not null default 0.45,
  similarite         numeric not null default 0.75,
  style_voix         numeric not null default 0.30,
  vitesse            numeric not null default 0.92,
  expressivite       text not null default 'medium',   -- low | medium | high (HeyGen)
  motion_prompt      text not null default 'Le Père Noël parle chaleureusement face caméra, légers mouvements de tête, sourire, clignements naturels, les mains restent hors du cadre.',
  duree_cible_sec    int not null default 75,
  consignes_script   text not null default '',
  updated_at         timestamptz not null default now()
);
insert into pn_reglages (id) values (1) on conflict (id) do nothing;

create table if not exists pn_commandes (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  reference         text unique not null,
  token             text unique not null default encode(gen_random_bytes(16), 'hex'),
  test              boolean not null default false,

  -- parent
  parent_prenom     text not null default '',
  email             text not null,

  -- enfant
  enfant_prenom     text not null,
  prononciation     text,
  age               int,
  genre             text,                 -- fille | garcon | null
  sagesse           text not null default 'tres_sage',   -- presque | tres_sage | le_plus_sage
  lettre            text,
  cadeaux           text,
  fierte            text,
  passion           text,
  effort            text,
  salut             text,
  secret            text,
  ton_secret        text not null default 'rigolo',      -- rigolo | tendre | serieux

  -- paiement
  montant_centimes  int not null default 0,
  checkout_id       text,
  statut            text not null default 'en_attente',  -- en_attente | payee | echouee | expiree
  transaction_code  text,
  paye_le           timestamptz,

  -- génération
  gen_statut        text not null default 'a_faire',     -- a_faire | relecture | audio | video | terminee | erreur
  script            text,
  lettre_reponse    text,
  certificat_mention text,
  audio_url         text,
  heygen_video_id   text,
  video_url         text,
  duree_sec         int,
  erreur            text,
  livre_le          timestamptz,
  email_envoye      boolean not null default false
);
create index if not exists pn_commandes_statut_idx on pn_commandes (statut, gen_statut);
create index if not exists pn_commandes_checkout_idx on pn_commandes (checkout_id);

-- Sécurité : tout passe par le serveur (service role). Lecture publique des réglages uniquement.
alter table pn_reglages enable row level security;
alter table pn_commandes enable row level security;
drop policy if exists pn_reglages_lecture on pn_reglages;
create policy pn_reglages_lecture on pn_reglages for select using (true);

-- Statistiques pour le tableau de bord
create or replace view pn_stats as
select
  count(*) filter (where statut = 'payee' and not test)                              as commandes,
  coalesce(sum(montant_centimes) filter (where statut = 'payee' and not test), 0)   as ca_centimes,
  count(*) filter (where statut = 'payee' and gen_statut = 'a_faire')                as a_generer,
  count(*) filter (where statut = 'payee' and gen_statut = 'relecture')              as a_relire,
  count(*) filter (where statut = 'payee' and gen_statut in ('audio','video'))        as en_cours,
  count(*) filter (where statut = 'payee' and gen_statut = 'terminee')               as livrees,
  count(*) filter (where statut = 'payee' and gen_statut = 'erreur')                 as en_erreur,
  coalesce(sum(duree_sec) filter (where gen_statut = 'terminee'), 0)                 as secondes_video
from pn_commandes;
EOF_PN_FICHIER
echo "  ✓ supabase/pere_noel.sql"
mkdir -p 'supabase'
cat > 'supabase/pere_noel_v2.sql' <<'EOF_PN_FICHIER'
-- Ajout : vidéo de démonstration sur la page d'accueil
alter table pn_reglages add column if not exists video_demo_url text;
EOF_PN_FICHIER
echo "  ✓ supabase/pere_noel_v2.sql"

git add -A && git commit -m "Père Noël : design féerique, vidéo démo, lettre et certificat ornés" && git push
vercel --prod
echo
echo "Puis : 1) SQL Supabase : alter table pn_reglages add column if not exists video_demo_url text;"
echo "       2) Vercel → Storage → cdf-blob → Upload demo-pere-noel.mp4 → coller l'URL dans Réglages → Vidéo de démonstration"
