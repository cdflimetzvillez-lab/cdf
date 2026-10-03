import { requireAdmin } from '@/lib/supabase/server';
import { contexte, referentiel } from '@/lib/compta/db';
import { aujourdhui } from '@/lib/compta/format';
import Entete from '@/components/compta/Entete';
import FormSaisie from '@/components/compta/FormSaisie';

export default async function Saisie() {
  const { supabase } = await requireAdmin();
  const [{ exercice }, { comptes, journaux, evenements }] = await Promise.all([
    contexte(supabase),
    referentiel(supabase),
  ]);

  return (
    <>
      <Entete titre="Saisie d'une écriture" />
      {exercice?.cloture && (
        <div className="cpt-msg ko">L&apos;exercice {exercice.libelle} est clôturé : les écritures datées de cet exercice seront refusées.</div>
      )}
      <FormSaisie comptes={comptes} journaux={journaux} evenements={evenements} dateDefaut={aujourdhui()} />
      <p className="cpt-info">
        Saisie ouverte aux admins et aux trésorières. Une écriture validée ne se supprime pas : elle s&apos;annule par une écriture inverse,
        depuis la fiche de la pièce.
      </p>
    </>
  );
}
