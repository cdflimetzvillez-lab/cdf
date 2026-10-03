const NOMBRE = new Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** 123456 centimes -> « 1 234,56 ». */
export function montant(centimes: number | null | undefined): string {
  return NOMBRE.format((centimes ?? 0) / 100);
}

/** Comme montant(), mais chaîne vide pour zéro (colonnes débit et crédit). */
export function montantOuVide(centimes: number | null | undefined): string {
  return centimes ? montant(centimes) : '';
}

/** Solde d'un compte : montant suivi de D (débiteur) ou C (créditeur). */
export function solde(centimes: number): string {
  if (!centimes) return '0,00';
  return `${montant(Math.abs(centimes))} ${centimes > 0 ? 'D' : 'C'}`;
}

/** « 1 234,56 », « 1234.5 » ou « 48,9 » -> centimes. Renvoie null si la saisie est invalide. */
export function enCentimes(saisie: string): number | null {
  const propre = saisie.replace(/[\s\u00a0\u202f€]/g, '').replace(',', '.');
  if (!/^\d+(\.\d{1,2})?$/.test(propre)) return null;
  return Math.round(parseFloat(propre) * 100);
}

/** 2026-10-03 -> 03/10/2026. */
export function dateFr(iso: string | null | undefined): string {
  if (!iso) return '';
  const [a, m, j] = iso.slice(0, 10).split('-');
  return `${j}/${m}/${a}`;
}

/** Date du jour à Paris, au format AAAA-MM-JJ. */
export function aujourdhui(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris' }).format(new Date());
}

export function estDateIso(v: string | undefined | null): v is string {
  return !!v && /^\d{4}-\d{2}-\d{2}$/.test(v);
}
