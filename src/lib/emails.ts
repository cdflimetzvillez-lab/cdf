/**
 * Gabarits d'emails — Comité des Fêtes de Limetz-Villez
 *
 * Contraintes des clients mail (Outlook en particulier) :
 *  - mise en page en tableaux, pas de flexbox ni de grid
 *  - styles en ligne, pas de feuille externe
 *  - polices système, les webfonts ne passent pas partout
 */

const NOIR = '#141014';
const CREME = '#FFF8EC';
const JAUNE = '#FFD400';
const GRIS = '#6b6560';

const MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août',
  'septembre','octobre','novembre','décembre'];
const JOURS = ['dimanche','lundi','mardi','mercredi','jeudi','vendredi','samedi'];

function dateLongue(iso?: string | null) {
  if (!iso) return '';
  const d = new Date(iso + 'T12:00:00');
  return `${JOURS[d.getDay()]} ${d.getDate()} ${MOIS[d.getMonth()]}`;
}

const euros = (c: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);

export interface DonneesBillet {
  nom: string;
  places: number;
  montant_centimes: number;
  code_billet: string;
  reference: string;
  commentaire?: string | null;
  /** Repas offert (bénévole, gagnant d'un jeu, invité) : le billet ne mentionne pas de montant réglé. */
  offert?: boolean;
  evenement: {
    titre: string;
    date_debut?: string | null;
    date_fin?: string | null;
    heure_debut?: string | null;
    heure_fin?: string | null;
    lieu?: string | null;
    adresse?: string | null;
    couleur?: string | null;
    slug?: string | null;
  };
}

/* ============================================================
   Confirmation de réservation
   ============================================================ */
export function billetHtml(d: DonneesBillet, urlSite: string): string {
  const couleur = d.evenement.couleur || '#FF3D7F';
  const quand = d.evenement.date_fin && d.evenement.date_fin !== d.evenement.date_debut
    ? `Du ${dateLongue(d.evenement.date_debut)} au ${dateLongue(d.evenement.date_fin)}`
    : dateLongue(d.evenement.date_debut);
  const horaire = [d.evenement.heure_debut, d.evenement.heure_fin]
    .filter(Boolean).join(' — ');

  const ligne = (cle: string, valeur: string) => `
    <tr>
      <td style="padding:10px 0;border-bottom:1px solid #E8E2D8;font-size:12px;
        letter-spacing:1px;text-transform:uppercase;color:${GRIS};">${cle}</td>
      <td style="padding:10px 0;border-bottom:1px solid #E8E2D8;font-size:15px;
        font-weight:bold;color:${NOIR};text-align:right;">${valeur}</td>
    </tr>`;

  return `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Votre réservation</title>
</head>
<body style="margin:0;padding:0;background:#EFEAE0;
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">

  <!-- texte d'aperçu, masqué -->
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
    Votre code billet : ${d.code_billet} — ${d.evenement.titre}
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
    style="background:#EFEAE0;padding:28px 12px;">
    <tr><td align="center">

      <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
        style="max-width:560px;background:${CREME};border:3px solid ${NOIR};">

        <!-- bandeau -->
        <tr>
          <td style="background:${couleur};padding:34px 28px;text-align:center;
            border-bottom:3px solid ${NOIR};">
            <div style="display:inline-block;background:${NOIR};color:${JAUNE};
              padding:6px 14px;font-size:11px;letter-spacing:2px;
              text-transform:uppercase;font-weight:bold;">
              Réservation confirmée
            </div>
            <h1 style="margin:18px 0 0;color:${CREME};font-size:30px;line-height:1.1;
              text-transform:uppercase;letter-spacing:-0.5px;">
              ${d.evenement.titre}
            </h1>
          </td>
        </tr>

        <!-- code billet -->
        <tr>
          <td style="padding:28px 28px 8px;text-align:center;">
            <p style="margin:0 0 6px;font-size:15px;color:${NOIR};">
              Bonjour ${d.nom},
            </p>
            <p style="margin:0 0 22px;font-size:15px;line-height:1.6;color:${NOIR};">
              Votre paiement est bien reçu. Présentez ce code à l'entrée.
            </p>

            <table role="presentation" cellpadding="0" cellspacing="0"
              style="margin:0 auto;border:3px dashed ${NOIR};background:#ffffff;">
              <tr><td style="padding:20px 34px;text-align:center;">
                <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;
                  color:${GRIS};margin-bottom:6px;">Code billet</div>
                <div style="font-size:34px;font-weight:bold;letter-spacing:4px;
                  color:${NOIR};">${d.code_billet}</div>
              </td></tr>
            </table>
          </td>
        </tr>

        <!-- détails -->
        <tr>
          <td style="padding:26px 28px 8px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
              ${quand ? ligne('Date', quand) : ''}
              ${horaire ? ligne('Horaires', horaire) : ''}
              ${d.evenement.lieu ? ligne('Lieu', d.evenement.lieu) : ''}
              ${ligne('Places', String(d.places))}
              ${d.offert ? ligne('Montant', 'Repas offert') : ligne('Montant réglé', euros(d.montant_centimes))}
              ${ligne('Référence', d.reference)}
            </table>
          </td>
        </tr>

        ${d.commentaire ? `
        <tr>
          <td style="padding:8px 28px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
              style="background:${JAUNE};border:2px solid ${NOIR};">
              <tr><td style="padding:12px 14px;font-size:13px;color:${NOIR};">
                <strong>Votre remarque :</strong> ${d.commentaire}
              </td></tr>
            </table>
          </td>
        </tr>` : ''}

        ${d.evenement.adresse ? `
        <tr>
          <td style="padding:16px 28px 0;font-size:13px;line-height:1.6;color:${GRIS};">
            <strong style="color:${NOIR};">Où nous trouver</strong><br>
            ${d.evenement.adresse}
          </td>
        </tr>` : ''}

        <!-- lien -->
        <tr>
          <td style="padding:26px 28px 30px;text-align:center;">
            <a href="${urlSite}${d.evenement.slug ? `/evenements/${d.evenement.slug}` : ''}"
              style="display:inline-block;background:${NOIR};color:${JAUNE};
              text-decoration:none;padding:14px 26px;font-size:13px;
              letter-spacing:1px;text-transform:uppercase;font-weight:bold;">
              Revoir le programme
            </a>
          </td>
        </tr>

        <!-- pied -->
        <tr>
          <td style="background:${NOIR};padding:22px 28px;text-align:center;">
            <p style="margin:0 0 6px;color:${JAUNE};font-size:13px;font-weight:bold;
              text-transform:uppercase;letter-spacing:1px;">
              Comité des Fêtes de Limetz-Villez
            </p>
            <p style="margin:0;color:#9a938c;font-size:11px;line-height:1.6;">
              Association loi 1901<br>
              Une question ? Répondez simplement à cet email.
            </p>
          </td>
        </tr>

      </table>

      <p style="max-width:560px;margin:16px auto 0;font-size:11px;color:#8a837c;
        text-align:center;line-height:1.6;">
        Cet email vous est envoyé suite à votre réservation ${d.reference}.
        Conservez-le, il fait office de billet.
      </p>

    </td></tr>
  </table>
</body>
</html>`;
}

/** Version texte, pour les clients qui n'affichent pas le HTML. */
export function billetTexte(d: DonneesBillet): string {
  const quand = dateLongue(d.evenement.date_debut);
  const horaire = [d.evenement.heure_debut, d.evenement.heure_fin]
    .filter(Boolean).join(' — ');

  return `Bonjour ${d.nom},

Votre réservation est confirmée. Présentez ce code à l'entrée :

    ${d.code_billet}

${d.evenement.titre}
${quand ? `Date       : ${quand}\n` : ''}${horaire ? `Horaires   : ${horaire}\n` : ''}${d.evenement.lieu ? `Lieu       : ${d.evenement.lieu}\n` : ''}Places     : ${d.places}
Montant    : ${d.offert ? 'Repas offert' : euros(d.montant_centimes)}
Référence  : ${d.reference}
${d.evenement.adresse ? `\nAdresse : ${d.evenement.adresse}\n` : ''}
Conservez cet email, il fait office de billet.
Une question ? Répondez simplement à ce message.

Le Comité des Fêtes de Limetz-Villez
Association loi 1901`;
}

/* ============================================================
   Notification interne : nouvelle réservation
   ============================================================ */
export function alerteReservationHtml(d: DonneesBillet): string {
  return `<!DOCTYPE html>
<html lang="fr"><head><meta charset="utf-8"></head>
<body style="margin:0;padding:20px;background:#EFEAE0;
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
    style="max-width:520px;margin:0 auto;background:${CREME};border:3px solid ${NOIR};">
    <tr><td style="background:#9BD44F;padding:18px 22px;border-bottom:3px solid ${NOIR};">
      <strong style="font-size:17px;text-transform:uppercase;">Nouvelle réservation</strong>
    </td></tr>
    <tr><td style="padding:22px;font-size:14px;line-height:1.8;color:${NOIR};">
      <strong>${d.nom}</strong> — ${d.places} place${d.places > 1 ? 's' : ''}
      pour <strong>${d.evenement.titre}</strong><br>
      Montant : ${d.offert ? 'Repas offert' : euros(d.montant_centimes)}<br>
      Référence : ${d.reference}<br>
      Code billet : ${d.code_billet}
      ${d.commentaire ? `<br><br><em>Remarque : ${d.commentaire}</em>` : ''}
    </td></tr>
  </table>
</body></html>`;
}
