/** Lien d'accès d'un compte : ouvert sur un téléphone, il y connecte le compte (voir /api/tresors/acces). */
export function lienAcces(token: string): string {
  const base = (process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000').replace(/\/$/, '');
  return `${base}/api/tresors/acces?token=${token}`;
}
