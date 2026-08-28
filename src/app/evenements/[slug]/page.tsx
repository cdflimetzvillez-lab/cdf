import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { createClient } from '@/lib/supabase/server';
import { createStaticClient } from '@/lib/supabase/static';
import MenuButton from '@/components/MenuButton';
import Marquee from '@/components/Marquee';
import Footer from '@/components/Footer';
import FormulaireDemande from '@/components/FormulaireDemande';
import FormulaireReservation from '@/components/FormulaireReservation';
import GalerieEvenement from '@/components/GalerieEvenement';
import { jourMois, horaires, dateLongue, periode, texteSur } from '@/lib/format';
import type { Evenement, Creneau, InfoBloc, FaqItem, SiteSettings } from '@/lib/types';

export const revalidate = 60;

export async function generateStaticParams() {
  const supabase = createStaticClient();
  const { data } = await supabase.from('evenements').select('slug').eq('publie', true);
  return (data ?? []).map((e) => ({ slug: e.slug }));
}

export async function generateMetadata(
  { params }: { params: Promise<{ slug: string }> }
): Promise<Metadata> {
  const { slug } = await params;
  const supabase = await createClient();
  const { data } = await supabase.from('evenements')
    .select('titre, chapo, image_url').eq('slug', slug).maybeSingle();
  if (!data) return { title: 'Événement introuvable' };
  return {
    title: `${data.titre} — Comité des Fêtes de Limetz-Villez`,
    description: data.chapo ?? undefined,
    openGraph: {
      title: data.titre,
      description: data.chapo ?? undefined,
      images: [{
        url: data.image_url ?? '/og-image.png',
        width: 1200, height: 630, alt: data.titre,
      }],
    },
  };
}

export default async function PageEvenement(
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params;
  const supabase = await createClient();

  const { data: evt } = await supabase.from('evenements')
    .select('*').eq('slug', slug).eq('publie', true).maybeSingle();
  if (!evt) notFound();
  const e = evt as Evenement;

  const [{ data: creneaux }, { data: infos }, { data: faq }, { data: documents }, { data: tarifs },
         { data: autres }, { data: settings }] = await Promise.all([
    supabase.from('creneaux').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('infos').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('faq').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('documents').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('tarifs').select('*').eq('evenement_id', e.id).order('position'),
    supabase.from('evenements').select('*').eq('publie', true).neq('id', e.id).order('position'),
    supabase.from('site_settings').select('*').eq('id', 1).single(),
  ]);

  const s = settings as SiteSettings;

  const { data: placesRestantes } = e.billetterie_active && e.places_max
    ? await supabase.rpc('places_restantes', { evt_id: e.id })
    : { data: null };

  const jm = jourMois(e.date_debut);
  const cr = (creneaux ?? []) as Creneau[];
  const tousDocs = (documents ?? []) as any[];
  const affiche = tousDocs.find((d) => d.est_affiche && d.type === 'image') ?? null;
  const autresDocs = tousDocs.filter((d) => d !== affiche);
  const grilleTarifs = (tarifs ?? []) as any[];
  const prixMini = grilleTarifs.length
    ? Math.min(...grilleTarifs.map((t) => t.prix_centimes))
    : e.prix_centimes;
  const plusieursTarifs = grilleTarifs.length > 1;
  const euros = (c: number) =>
    new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(c / 100);


  return (
    <div style={{ ['--evt' as string]: e.couleur, ['--evt-dark' as string]: e.couleur_sombre }}>
      <MenuButton />
      <Link className="crumb" href="/#evenements">← Tous les événements</Link>

      <header
        className={`ehero${e.image_url ? ' avec-image' : ''}`}
        style={e.image_url ? { backgroundImage: `url(${e.image_url})` } : undefined}
      >
        <div className="ehero-inner">
          <span className="badge-num">{periode(e.date_debut, e.date_fin)}</span>
          <h1>{e.titre}</h1>
          {e.chapo && <p className="ehero-lead">{e.chapo}</p>}

          <div className="keys">
            <div className="key">
              <div className="k">Date</div>
              <div className="v">{jm.jour} {jm.date}</div>
            </div>
            <div className="key">
              <div className="k">Horaires</div>
              <div className="v">{horaires(e.heure_debut, e.heure_fin)}</div>
            </div>
            <div className="key">
              <div className="k">Lieu</div>
              <div className="v">{e.lieu}</div>
            </div>
            <div className="key">
              <div className="k">Tarif</div>
              <div className="v">
                {e.billetterie_active && prixMini > 0 ? (
                  <>
                    {plusieursTarifs && <small>À partir de</small>}
                    {euros(prixMini)}
                  </>
                ) : e.tarif}
              </div>
            </div>
          </div>

          <div className="ehero-cta">
            {cr.length > 0 && <a className="btn btn-y" href="#programme">Voir le programme</a>}
            <a className="btn btn-w" href={e.billetterie_active ? '#reserver' : '#participer'}>
              {e.billetterie_active ? e.libelle_reservation : 'Participer'}
            </a>
            {infos && infos.length > 0 && <a className="btn btn-k" href="#infos">Y aller</a>}
          </div>
        </div>
      </header>

      {cr.length > 0 && (
        <Marquee items={cr.map((c) => `${c.heure} ${c.titre}`)} />
      )}

      {cr.length > 0 && (
        <section id="programme">
          <div className="wrap">
            <div className="head">
              <h2>Le déroulé</h2>
              {e.description && <p>{e.description}</p>}
            </div>
            <div className={affiche ? 'prog-avec-affiche' : ''}>
            {affiche && (
              <a className="prog-affiche" href={affiche.url} target="_blank" rel="noreferrer">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={affiche.url} alt={affiche.titre ?? "Affiche de l'événement"} />
                <span>Voir en grand</span>
              </a>
            )}
            <div className="timeline">
              {cr.map((c) => (
                <div className="slot" key={c.id}>
                  <div className="t">{c.heure}</div>
                  <div className="h">{c.titre}</div>
                  {c.description && <p>{c.description}</p>}
                  {c.scene && <span className="stage">{c.scene}</span>}
                </div>
              ))}
            </div>
            </div>
          </div>
        </section>
      )}

      {infos && infos.length > 0 && (
        <section className="info" id="infos">
          <div className="wrap">
            <div className="head">
              <h2>Infos pratiques</h2>
              <p>Tout ce qu&apos;il faut savoir avant de venir.</p>
            </div>
            <div className="info-grid">
              {(infos as InfoBloc[]).map((b) => (
                <div className="icard" key={b.id}>
                  <h3>{b.titre}</h3>
                  <ul>{b.lignes.map((l, i) => <li key={i}>{l}</li>)}</ul>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}

      {e.billetterie_active ? (
        <section className="take" id="reserver">
          <div className="wrap take-grid">
            <div>
              <h2>Réservez votre place</h2>
              <p style={{ marginTop: '1rem', fontWeight: 600, maxWidth: '44ch', lineHeight: 1.6 }}>
                Paiement en ligne sécurisé. Votre billet vous est envoyé par email
                dès le règlement effectué.
              </p>
            </div>
            <FormulaireReservation
              evenementId={e.id}
              tarifs={grilleTarifs}
              prixCentimes={e.prix_centimes}
              placesMax={e.places_par_reservation}
              placesRestantes={placesRestantes as number | null}
              cloture={e.cloture_reservations}
            />
          </div>
        </section>
      ) : (
        <section className="take" id="participer">
          <div className="wrap take-grid">
            <div>
              <h2>Participer à l&apos;organisation</h2>
              <p style={{ marginTop: '1rem', fontWeight: 600, maxWidth: '44ch', lineHeight: 1.6 }}>
                Exposant, musicien, ou simple coup de main pour le montage : dites-nous
                ce que vous proposez, le comité vous répond.
              </p>
            </div>
            <FormulaireDemande evenementId={e.id} />
          </div>
        </section>
      )}

      {autresDocs.length > 0 && (
        <section id="documents">
          <div className="wrap">
            <div className="head">
              <h2>Affiches et documents</h2>
              <p>Cliquez pour agrandir.</p>
            </div>
            <GalerieEvenement documents={autresDocs as any} />
          </div>
        </section>
      )}

      {faq && faq.length > 0 && (
        <section>
          <div className="wrap">
            <div className="head"><h2>Questions fréquentes</h2></div>
            <div className="faq">
              {(faq as FaqItem[]).map((f, i) => (
                <details key={f.id} open={i === 0}>
                  <summary>{f.question}</summary>
                  <p>{f.reponse}</p>
                </details>
              ))}
            </div>
          </div>
        </section>
      )}

      {autres && autres.length > 0 && (
        <section style={{ borderTop: '4px solid var(--noir)' }}>
          <div className="wrap">
            <div className="head"><h2>Les autres rendez-vous</h2></div>
            <div className="grid">
              {(autres as Evenement[]).map((o) => {
                const fg = texteSur(o.couleur);
                return (
                  <Link
                    key={o.id}
                    href={`/evenements/${o.slug}`}
                    className={`poster${fg === '#FFF8EC' ? ' dark' : ''}`}
                    style={{ background: o.couleur, color: fg, minHeight: 200 }}
                  >
                    <div>
                      <div className="when">{dateLongue(o.date_debut)}</div>
                      <h3>{o.titre}</h3>
                    </div>
                    <span className="price">{o.tarif}</span>
                  </Link>
                );
              })}
            </div>
          </div>
        </section>
      )}

      <Footer settings={s} evenements={(autres ?? []) as Evenement[]} />
    </div>
  );
}
