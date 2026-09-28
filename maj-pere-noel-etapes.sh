#!/usr/bin/env bash
# Mise à jour : bouton lecture vectoriel + formulaire une étape à la fois avec glissement.
# À exécuter à la racine du projet :  bash maj-pere-noel-etapes.sh
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
.pn [hidden]{display:none!important}
.pn form>.pn-carte:not([hidden]){animation:pn-glisse .38s cubic-bezier(.2,.8,.2,1)}
@keyframes pn-glisse{from{opacity:0;transform:translateX(40px)}to{opacity:1;transform:none}}
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
.pn-demo .play{width:78px;height:78px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#FFF6D6,var(--pn-or) 60%,var(--pn-or2));color:#5A3A0A;display:flex;align-items:center;justify-content:center;padding-left:5px;border:2px solid rgba(255,255,255,.55);
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
        <div className="play" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="30" height="30" fill="currentColor"><path d="M8 5.5v13a1 1 0 0 0 1.53.85l10.2-6.5a1 1 0 0 0 0-1.7L9.53 4.65A1 1 0 0 0 8 5.5z" /></svg>
        </div>
        <div className="legende">Écoute le Père Noël répondre à Léa</div>
        <div className="sous">Un exemple de vidéo, telle que la recevra ton enfant</div>
      </div>
    </div>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/DemoVideo.tsx"
mkdir -p 'src/components/pere-noel'
cat > 'src/components/pere-noel/FormCommande.tsx' <<'EOF_PN_FICHIER'
'use client';
import { useActionState, useEffect, useState } from 'react';
import { commander, type Etat } from '@/app/pere-noel-actions';
import { euros } from '@/lib/sumup';
import { LIBELLE_SAGESSE, type Sagesse, type TonSecret } from '@/lib/pere-noel/types';

const EFFORTS = ['Dormir dans son lit', 'Goûter les légumes', 'Ranger sa chambre', 'Être gentil avec son frère ou sa sœur', 'Moins d’écrans', 'Se brosser les dents sans râler'];
const NOMS_ETAPES = ['L’enfant', 'Sa lettre', 'Les détails', 'Le secret', 'Récapitulatif'];

export default function FormCommande({ prix, test }: { prix: number; test: boolean }) {
  const [etat, action, pending] = useActionState<Etat, FormData>(commander, null);
  const [etape, setEtape] = useState(1);
  useEffect(() => { if (typeof window !== 'undefined') window.scrollTo({ top: 0, behavior: 'smooth' }); }, [etape]);
  const [f, setF] = useState({
    enfant_prenom: '', prononciation: '', age: '', genre: '', sagesse: 'tres_sage' as Sagesse,
    lettre: '', cadeaux: '', fierte: '', passion: '', effort: '', effortAutre: '', salut: '',
    secret: '', ton_secret: 'rigolo' as TonSecret, parent_prenom: '', email: '',
  });
  const maj = (k: keyof typeof f, v: string) => setF((x) => ({ ...x, [k]: v }));
  const enfantOk = f.enfant_prenom.trim().length > 0 && Number(f.age) > 0;
  const lettreOk = f.lettre.trim().length > 0 || f.cadeaux.trim().length > 0;
  const parentOk = f.parent_prenom.trim().length > 0 && f.email.includes('@');
  const effortFinal = f.effort === 'autre' ? f.effortAutre : f.effort;

  return (
    <form action={action}>
      <input type="hidden" name="test" value={test ? '1' : '0'} />
      <input type="hidden" name="effort" value={effortFinal} />
      <div className="pn-steps" aria-hidden="true">{[1, 2, 3, 4, 5].map((n) => <i key={n} className={n <= etape ? 'on' : ''} />)}</div>
      <div className="pn-stepname">Étape {etape} sur 5 · {NOMS_ETAPES[etape - 1]}</div>
      {etat?.erreur && <p className="pn-erreur" role="alert">{etat.erreur}</p>}
      {test && <p className="pn-cardn pn-mini">Mode test administrateur : pas de paiement, la commande est créée directement.</p>}

      {/* 1. L'enfant */}
      <section className="pn-carte" hidden={etape !== 1}>
        <h2>Pour qui est cette vidéo ?</h2>
        <p className="pn-l">Le Père Noël prononcera son prénom, écrivez-le comme on le dit.</p>
        <div className="pn-champ"><label htmlFor="enfant_prenom">Prénom de l&apos;enfant</label>
          <input id="enfant_prenom" name="enfant_prenom" value={f.enfant_prenom} onChange={(e) => maj('enfant_prenom', e.target.value)} autoComplete="off" /></div>
        <div className="pn-champ"><label htmlFor="prononciation">Comment on le prononce (si besoin)</label>
          <input id="prononciation" name="prononciation" placeholder="Ex. : Maël se dit « Ma-el »" value={f.prononciation} onChange={(e) => maj('prononciation', e.target.value)} /></div>
        <div className="pn-row">
          <div className="pn-champ"><label htmlFor="age">Âge</label>
            <input id="age" name="age" type="number" inputMode="numeric" min={1} max={17} value={f.age} onChange={(e) => maj('age', e.target.value)} /></div>
          <div className="pn-champ"><label htmlFor="genre">Fille ou garçon</label>
            <select id="genre" name="genre" value={f.genre} onChange={(e) => maj('genre', e.target.value)}>
              <option value="">Je préfère ne pas dire</option><option value="fille">Fille</option><option value="garcon">Garçon</option></select></div>
        </div>
        <div className="pn-champ"><label>A-t-il été sage cette année ?</label>
          <div className="pn-opts">
            {([['presque', '~'], ['tres_sage', '★'], ['le_plus_sage', '★★']] as [Sagesse, string][]).map(([v, s]) => (
              <label key={v} className={f.sagesse === v ? 'on' : ''}><input type="radio" name="sagesse" value={v} checked={f.sagesse === v} onChange={() => maj('sagesse', v)} /><b>{s}</b>{LIBELLE_SAGESSE[v]}</label>
            ))}
          </div></div>
        <button type="button" className="pn-btn" disabled={!enfantOk} onClick={() => setEtape(2)}>Continuer</button>
      </section>

      {/* 2. Sa lettre */}
      <section className="pn-carte" hidden={etape !== 2}>
        <h2>Qu&apos;est-ce que {f.enfant_prenom || 'votre enfant'} veut dire au Père Noël ?</h2>
        <p className="pn-l">Écrivez ce qu&apos;il vous dicte, avec ses mots. C&apos;est à cette lettre que le Père Noël va répondre. S&apos;il pose une question, le Père Noël y répondra.</p>
        <div className="pn-champ"><label htmlFor="lettre">Sa lettre</label>
          <textarea id="lettre" name="lettre" placeholder="Cher Père Noël, cette année j'ai appris à…" value={f.lettre} onChange={(e) => maj('lettre', e.target.value)} maxLength={1500} /></div>
        <div className="pn-champ"><label htmlFor="cadeaux">Ce qu&apos;il demande comme cadeau (pour que le Père Noël en parle)</label>
          <input id="cadeaux" name="cadeaux" placeholder="Un microscope, un livre sur les dauphins" value={f.cadeaux} onChange={(e) => maj('cadeaux', e.target.value)} /></div>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(1)}>Retour</button>
          <button type="button" className="pn-btn" disabled={!lettreOk} onClick={() => setEtape(3)}>Continuer</button>
        </div>
      </section>

      {/* 3. Les détails */}
      <section className="pn-carte" hidden={etape !== 3}>
        <h2>Ce que le Père Noël sait sur {f.enfant_prenom || 'lui'}</h2>
        <p className="pn-l">Tout est facultatif. Plus vous remplissez, plus la vidéo est bluffante.</p>
        <div className="pn-champ"><label htmlFor="fierte">Sa grande fierté de l&apos;année</label>
          <input id="fierte" name="fierte" placeholder="A appris à faire du vélo sans les petites roues" value={f.fierte} onChange={(e) => maj('fierte', e.target.value)} /></div>
        <div className="pn-champ"><label htmlFor="passion">Son doudou, son animal ou sa passion</label>
          <input id="passion" name="passion" placeholder="Son lapin Caramel et les dauphins" value={f.passion} onChange={(e) => maj('passion', e.target.value)} /></div>
        <div className="pn-champ"><label>Un petit effort à encourager (le Père Noël le demande gentiment)</label>
          <div className="pn-chips">
            {EFFORTS.map((e) => <label key={e} className={f.effort === e ? 'on' : ''}><input type="radio" name="effort_choix" checked={f.effort === e} onChange={() => maj('effort', e)} />{e}</label>)}
            <label className={f.effort === 'autre' ? 'on' : ''}><input type="radio" name="effort_choix" checked={f.effort === 'autre'} onChange={() => maj('effort', 'autre')} />Autre…</label>
            {f.effort && <label className="on" style={{ background: 'transparent', color: 'var(--pn-encre2)', borderStyle: 'dashed' }} onClick={() => maj('effort', '')}>✕ aucun</label>}
          </div>
          {f.effort === 'autre' && <input style={{ marginTop: 8 }} placeholder="Ex. : arrêter de mordre son frère" value={f.effortAutre} onChange={(e) => maj('effortAutre', e.target.value)} />}
        </div>
        <div className="pn-champ"><label htmlFor="salut">Une personne à saluer (mamie, la maîtresse, le petit frère…)</label>
          <input id="salut" name="salut" placeholder="Mamie Jacqueline" value={f.salut} onChange={(e) => maj('salut', e.target.value)} /></div>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(2)}>Retour</button>
          <button type="button" className="pn-btn" onClick={() => setEtape(4)}>Continuer</button>
        </div>
      </section>

      {/* 4. Le secret */}
      <section className="pn-carte" hidden={etape !== 4}>
        <h2>Un mot que seul le Père Noël pouvait connaître</h2>
        <p className="pn-l">Un détail que votre enfant n&apos;a dit à personne, une petite bêtise pardonnée, un souvenir… Le Père Noël le glisse dans la vidéo. C&apos;est ce qui le fera écarquiller les yeux. Facultatif.</p>
        <div className="pn-champ"><label htmlFor="secret">Le message secret</label>
          <textarea id="secret" name="secret" placeholder="Elle a caché les bonbons d'Halloween dans sa boîte à chaussures et pense que personne ne le sait." value={f.secret} onChange={(e) => maj('secret', e.target.value)} maxLength={500} style={{ minHeight: 90 }} /></div>
        <div className="pn-champ"><label>Comment le Père Noël doit le dire</label>
          <div className="pn-opts">
            {([['rigolo', '☺', 'En rigolant'], ['tendre', '♥', 'Avec tendresse'], ['serieux', '!', 'Un peu sérieux']] as [TonSecret, string, string][]).map(([v, s, l]) => (
              <label key={v} className={f.ton_secret === v ? 'on' : ''}><input type="radio" name="ton_secret" value={v} checked={f.ton_secret === v} onChange={() => maj('ton_secret', v)} /><b>{s}</b>{l}</label>
            ))}
          </div></div>
        <p className="pn-l pn-mini" style={{ marginTop: 12 }}>Le message secret n&apos;apparaît que dans la vidéo, jamais sur la lettre ni le certificat.</p>
        <div className="pn-row">
          <button type="button" className="pn-btn sec" onClick={() => setEtape(3)}>Retour</button>
          <button type="button" className="pn-btn" onClick={() => setEtape(5)}>Continuer</button>
        </div>
      </section>

      {/* 5. Récap + parent */}
      <section className="pn-carte" hidden={etape !== 5}>
        <h2>On envoie la lettre de {f.enfant_prenom || 'votre enfant'} ?</h2>
        <dl className="pn-recap" style={{ margin: 0 }}>
          <dt>Pour</dt><dd>{f.enfant_prenom}, {f.age} ans, {LIBELLE_SAGESSE[f.sagesse]}</dd>
          {(f.fierte || f.passion || f.salut || effortFinal) && <><dt>Le Père Noël va parler de</dt><dd>{[f.fierte, f.passion, f.salut, effortFinal].filter(Boolean).join(' · ')}</dd></>}
          {f.secret && <><dt>Message secret</dt><dd>Oui, {({ rigolo: 'en rigolant', tendre: 'avec tendresse', serieux: 'un peu sérieux' })[f.ton_secret]}</dd></>}
        </dl>
        <div className="pn-champ"><label htmlFor="parent_prenom">Votre prénom</label>
          <input id="parent_prenom" name="parent_prenom" autoComplete="given-name" value={f.parent_prenom} onChange={(e) => maj('parent_prenom', e.target.value)} /></div>
        <div className="pn-champ"><label htmlFor="email">Votre email (pour recevoir la vidéo)</label>
          <input id="email" name="email" type="email" inputMode="email" autoComplete="email" value={f.email} onChange={(e) => maj('email', e.target.value)} /></div>
        <div style={{ marginTop: 14 }}>
          <div className="pn-prix"><span>Vidéo réponse du Père Noël</span><span>{test ? 'test' : euros(prix)}</span></div>
          <div className="pn-prix"><span>Lettre écrite + certificat d&apos;enfant sage</span><span>inclus</span></div>
          <div className="pn-prix total"><span>Total</span><span>{test ? '0 €' : euros(prix)}</span></div>
        </div>
        <button type="submit" className="pn-btn vert" disabled={!parentOk || pending}>
          {pending ? 'Redirection…' : test ? 'Créer la commande de test' : `Payer ${euros(prix)} par carte`}
        </button>
        <p className="pn-l pn-mini pn-centre" style={{ marginTop: 10 }}>Paiement sécurisé par SumUp. Vidéo livrée par email, garantie satisfait ou refait.</p>
        <button type="button" className="pn-lien" onClick={() => setEtape(1)}>Modifier les réponses</button>
      </section>
    </form>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/components/pere-noel/FormCommande.tsx"

git add -A && git commit -m "Père Noël : bouton lecture vectoriel, une étape à la fois avec glissement" && git push
vercel --prod
