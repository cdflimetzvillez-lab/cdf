'use client';
import { CLES_ADMIN } from '@/lib/tresors/mock';

/** Export CSV des clés (démo, données mock). */
export default function ExportCles() {
  function exporter() {
    const lignes = [
      ['numero', 'code', 'prenom', 'lot', 'revelee'],
      ...CLES_ADMIN.map((c) => [c.numero, c.code, c.prenom, c.lot, c.revelee ? 'oui' : 'non']),
    ];
    const csv = lignes.map((l) => l.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(';')).join('\n');
    const url = URL.createObjectURL(new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a');
    a.href = url; a.download = 'cles-tresors-de-noel.csv'; a.click();
    URL.revokeObjectURL(url);
  }
  return <button className="btn btn-k btn-sm" onClick={exporter}>Exporter les clés</button>;
}
