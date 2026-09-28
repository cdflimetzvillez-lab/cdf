import 'server-only';
import type { CommandePn, ReglagesPn } from './types';

const NUIT = '#1B2A4A';
const ROUGE = '#B8322E';
const OR = '#D4A64A';
const PAPIER = '#F7EFDD';
const ENCRE = '#2A2116';

function base() { return process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000'; }

function gabarit(titre: string, corps: string) {
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${titre}</title></head>
<body style="margin:0;padding:0;background:#EFEAE0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#EFEAE0;padding:28px 12px;"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:${PAPIER};border:3px solid ${NUIT};">
<tr><td style="background:${NUIT};padding:30px 28px;text-align:center;">
<div style="font-family:Georgia,serif;font-size:14px;color:${OR};letter-spacing:1px;">Le Père Noël te répond</div>
<h1 style="margin:12px 0 0;color:${PAPIER};font-family:Georgia,serif;font-weight:normal;font-size:26px;line-height:1.2;">${titre}</h1>
</td></tr>
<tr><td style="padding:26px 28px;color:${ENCRE};font-size:15px;line-height:1.6;">${corps}</td></tr>
<tr><td style="padding:16px 28px 22px;border-top:1px solid #E2D6B6;font-size:12px;color:#6B5E4C;">Une action du Comité des Fêtes. Les bénéfices financent les événements de l'année.</td></tr>
</table></td></tr></table></body></html>`;
}

function bouton(url: string, libelle: string) {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:22px auto;"><tr><td style="background:${ROUGE};padding:14px 26px;text-align:center;">
<a href="${url}" style="color:#ffffff;text-decoration:none;font-family:Georgia,serif;font-size:16px;">${libelle}</a></td></tr></table>`;
}

async function envoyer(to: string, subject: string, html: string, text: string) {
  if (!process.env.RESEND_API_KEY) { console.warn('[pere-noel] RESEND_API_KEY absente, email non envoyé'); return false; }
  const from = process.env.RESEND_FROM_EMAIL ?? 'Comité des Fêtes de Limetz-Villez <billetterie@cdf-limetzvillez.fr>';
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from, to: [to], subject, html, text }),
  });
  if (!r.ok) console.error('[pere-noel] Resend', r.status, await r.text());
  return r.ok;
}

/** Après paiement : la lettre est partie, certificat et lettre écrite dès que le script est prêt. */
export async function emailConfirmation(c: CommandePn, r: ReglagesPn) {
  const lien = `${base()}/pere-noel/ma-video/${c.token}`;
  const corps = `
<p>Bonjour ${c.parent_prenom || ''},</p>
<p>La lettre de ${c.enfant_prenom} est bien arrivée au Pôle Nord. Le Père Noël prépare sa réponse en vidéo, vous la recevrez par email ${r.delai_texte}.</p>
<p>Votre espace personnel vous permettra de regarder la vidéo, de la télécharger et d'imprimer la lettre écrite du Père Noël ainsi que le certificat d'enfant sage :</p>
${bouton(lien, 'Ouvrir mon espace')}
<p style="font-size:13px;color:#6B5E4C;">Référence de commande : ${c.reference}. Ce lien est personnel, ne le partagez pas avec votre enfant.</p>`;
  const text = `Bonjour ${c.parent_prenom || ''},\n\nLa lettre de ${c.enfant_prenom} est bien arrivée au Pôle Nord. Vous recevrez la vidéo ${r.delai_texte}.\n\nVotre espace : ${lien}\nRéférence : ${c.reference}\n\nComité des Fêtes de Limetz-Villez`;
  return envoyer(c.email, `La lettre de ${c.enfant_prenom} est arrivée au Pôle Nord`, gabarit('La lettre est bien arrivée', corps), text);
}

/** Vidéo prête : lien vers l'espace avec lecture et téléchargement. */
export async function emailVideoPrete(c: CommandePn) {
  const lien = `${base()}/pere-noel/ma-video/${c.token}`;
  const corps = `
<p>Bonjour ${c.parent_prenom || ''},</p>
<p>La réponse du Père Noël à ${c.enfant_prenom} est prête. Elle vous attend dans votre espace, avec le bouton de téléchargement, la lettre écrite et le certificat à imprimer.</p>
${bouton(lien, 'Voir la vidéo du Père Noël')}
<p>Un conseil : ne la montrez pas tout de suite. Le soir, dans le noir, sur la télé du salon, l'effet est décuplé.</p>
<p style="font-size:13px;color:#6B5E4C;">Pensez à télécharger la vidéo, elle reste disponible jusqu'au 31 janvier. Référence : ${c.reference}.</p>`;
  const text = `Bonjour ${c.parent_prenom || ''},\n\nLa réponse du Père Noël à ${c.enfant_prenom} est prête : ${lien}\n\nPensez à la télécharger, elle reste disponible jusqu'au 31 janvier.\n\nComité des Fêtes de Limetz-Villez`;
  return envoyer(c.email, `Le Père Noël a répondu à ${c.enfant_prenom}`, gabarit(`La vidéo de ${c.enfant_prenom} est prête`, corps), text);
}
