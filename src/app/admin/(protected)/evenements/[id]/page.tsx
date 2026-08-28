import { notFound } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/server';
import EditeurEvenement from '@/components/EditeurEvenement';
import type { Evenement, Creneau, InfoBloc, FaqItem } from '@/lib/types';

export default async function PageEditeur(
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const { supabase } = await requireAdmin();

  if (id === 'nouveau') {
    return (
      <>
        <div className="adm-h">
          <div>
            <h1>Nouvel événement</h1>
            <p>Il restera en brouillon tant que vous ne cochez pas « publier ».</p>
          </div>
        </div>
        <EditeurEvenement evenement={null} creneaux={[]} infos={[]} faq={[]} />
      </>
    );
  }

  const { data: evt } = await supabase.from('evenements').select('*').eq('id', id).maybeSingle();
  if (!evt) notFound();

  const [{ data: creneaux }, { data: infos }, { data: faq }, { data: documents }, { data: tarifs }] =
    await Promise.all([
      supabase.from('creneaux').select('*').eq('evenement_id', id).order('position'),
      supabase.from('infos').select('*').eq('evenement_id', id).order('position'),
      supabase.from('faq').select('*').eq('evenement_id', id).order('position'),
      supabase.from('documents').select('*').eq('evenement_id', id).order('position'),
      supabase.from('tarifs').select('*').eq('evenement_id', id).order('position'),
    ]);

  return (
    <>
      <div className="adm-h">
        <div>
          <h1>{(evt as Evenement).titre}</h1>
          <p>Modifiez le contenu, le programme et les infos pratiques de cette page.</p>
        </div>
      </div>
      <EditeurEvenement
        evenement={evt as Evenement}
        creneaux={(creneaux ?? []) as Creneau[]}
        infos={(infos ?? []) as InfoBloc[]}
        faq={(faq ?? []) as FaqItem[]}
        documents={(documents ?? []).map((d: any) => ({
          url: d.url, titre: d.titre ?? '', legende: d.legende ?? '',
          type: d.type, est_affiche: d.est_affiche,
        }))}
        tarifs={(tarifs ?? []).map((t: any) => ({
          libelle: t.libelle,
          description: t.description ?? '',
          prix_euros: (t.prix_centimes / 100).toFixed(2),
        }))}
      />
    </>
  );
}
