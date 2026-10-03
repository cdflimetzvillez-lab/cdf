'use client';

type Props = {
  nom: string;
  entetes: string[];
  lignes: (string | number | null)[][];
  libelle?: string;
};

const echappe = (v: string | number | null) => `"${String(v ?? '').replace(/"/g, '""')}"`;

/** Export CSV (séparateur point-virgule, BOM UTF-8 pour Excel). */
export default function ExportCsvCompta({ nom, entetes, lignes, libelle = 'Exporter en CSV' }: Props) {
  function telecharger() {
    const csv = '\uFEFF' + [entetes, ...lignes].map((l) => l.map(echappe).join(';')).join('\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8;' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = `${nom}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }
  return (
    <button type="button" className="cpt-btn" onClick={telecharger} disabled={lignes.length === 0}>
      {libelle}
    </button>
  );
}
