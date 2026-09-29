#!/usr/bin/env bash
# Correctif : lien « Trésors de Noël » affiché aux visiteurs alors que le module est désactivé.
set -euo pipefail
if [ ! -f package.json ] || [ ! -d src/app ]; then echo "Lance ce script à la racine du repo."; exit 1; fi
mkdir -p 'src/app'
cat > 'src/app/page.tsx' <<'EOF_PN_FICHIER'
import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import MenuButton from '@/components/MenuButton';
import RetourHaut from '@/components/RetourHaut';
import Marquee from '@/components/Marquee';
import Footer from '@/components/Footer';
import RoueRentree from '@/components/roue/RoueRentree';
import BandeauPartenaires from '@/components/BandeauPartenaires';
import { configRoue, getWheelConfig, roueVisible } from '@/lib/roue/db';
import { dateCourte, dateLongue, horaires, periode, texteSur } from '@/lib/format';
import type { Partenaire, SiteSettings, Stat, Evenement } from '@/lib/types';

export const revalidate = 60;

export default async function Home() {
  const supabase = await createClient();

  const [{ data: settings }, { data: stats }, { data: evenements }, wheelConfig, { data: partenaires }, { data: tdn }, { data: pn }] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(),
    supabase.from('stats').select('*').order('position'),
    supabase.from('evenements').select('*').eq('publie', true).order('position'),
    getWheelConfig(),
    supabase.from('partenaires').select('*').eq('actif', true).order('position'),
    supabase.from('tdn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
    supabase.from('pn_reglages').select('module_actif').eq('id', 1).maybeSingle(),
  ]);
  // Module événementiel : rendu côté serveur uniquement si actif et dans la période.
  const showWheel = roueVisible(wheelConfig);

  const s = settings as SiteSettings;
  const evts = (evenements ?? []) as Evenement[];

  return (
    <>
      <MenuButton tresors={tdn?.module_actif === true} pereNoel={pn?.module_actif === true} />
      <RetourHaut />

      <header className="hero" style={{ ['--evt' as string]: s.hero_couleur }}>
        <div className="hero-inner">
          <div className="logo-badge">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              className="hero-logo"
              src={s.logo_url || '/logo-cdf.png'}
              alt="Comité des Fêtes de Limetz-Villez"
            />
          </div>
          <div style={{ marginBottom: '2.4rem' }}>
            <span className="kicker mono">{s.hero_kicker}</span>
          </div>
          <h1>
            {s.hero_titre_1} <span className="jaune">{s.hero_titre_accent}</span>
            <br />
            <span className="cyan">{s.hero_titre_2}</span>
          </h1>
          <p className="hero-tag">{s.hero_texte}</p>
          <div className="hero-cta">
            <a className="btn btn-y" href="#evenements">Voir le programme</a>
            <a className="btn btn-w" href="#benevoles">Devenir bénévole</a>
          </div>
        </div>

        <a className="scroll-hint" href="#evenements">
          <span>Faire défiler</span>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3"
               strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M6 9l6 6 6-6" />
          </svg>
        </a>
      </header>

      <Marquee items={evts.map((e) => `${dateCourte(e.date_debut)} · ${e.titre}`)} />

      {showWheel && <RoueRentree config={configRoue(wheelConfig)} />}

      <section id="evenements">
        <div className="wrap">
          <div className="head">
            <h2>Le programme</h2>
            <p>Nos rendez-vous de l&apos;année. Cliquez pour les horaires, le lieu et les inscriptions.</p>
          </div>
          <div className="grid">
            {evts.map((e, i) => {
              const fg = texteSur(e.couleur);
              return (
                <Link
                  key={e.id}
                  href={`/evenements/${e.slug}`}
                  className={`poster${fg === '#FFF8EC' ? ' dark' : ''}`}
                  style={{ background: e.couleur, color: fg }}
                >
                  <span className="num">{String(i + 1).padStart(2, '0')}</span>
                  <div>
                    <div className="when">
                      {periode(e.date_debut, e.date_fin)}{horaires(e.heure_debut, e.heure_fin) && ` · ${horaires(e.heure_debut, e.heure_fin)}`}
                    </div>
                    <h3>{e.titre}</h3>
                    <p>{e.chapo}</p>
                  </div>
                  <span className="price">{e.tarif}</span>
                </Link>
              );
            })}
          </div>
        </div>
        <BandeauPartenaires partenaires={(partenaires ?? []) as Partenaire[]} />
      </section>

      <section className="about" id="association">
        <div className="wrap">
          <div className="head"><h2>{s.asso_titre}</h2></div>
          <div className="about-grid">
            <div>
              {s.asso_texte.split('\n\n').map((p, i) => <p key={i}>{p}</p>)}
            </div>
            <div className="stats">
              {(stats as Stat[] ?? []).map((st) => (
                <div className="stat" key={st.id}>
                  <b>{st.valeur}</b>
                  <span>{st.libelle}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="join" id="benevoles">
        <div className="mono" style={{ marginBottom: '1rem' }}>On a besoin de bras</div>
        <h2>{s.benevoles_titre}</h2>
        <p>{s.benevoles_texte}</p>
        <a className="btn btn-y" href={`mailto:${s.email_contact}`}>Nous contacter</a>
      </section>

      <Footer settings={s} evenements={evts} />
    </>
  );
}
EOF_PN_FICHIER
echo "  ✓ src/app/page.tsx"
mkdir -p 'src/app/evenements/[slug]'
cat > 'src/app/evenements/[slug]/page.tsx' <<'EOF_PN_FICHIER'
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
  const { data: tdn } = await supabase.from('tdn_reglages').select('module_actif').eq('id', 1).maybeSingle();
  const tdnActif = tdn?.module_actif === true;
  const { data: pn } = await supabase.from('pn_reglages').select('module_actif').eq('id', 1).maybeSingle();
  const pnActif = pn?.module_actif === true;

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
      <MenuButton tresors={tdnActif} pereNoel={pnActif} />
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
EOF_PN_FICHIER
echo "  ✓ src/app/evenements/[slug]/page.tsx"
mkdir -p 'supabase'
cat > 'supabase/pere_noel_v4.sql' <<'EOF_PN_FICHIER'
-- Lecture publique des réglages Trésors de Noël (pour afficher ou masquer le lien du menu aux visiteurs)
drop policy if exists tdn_reglages_lecture on tdn_reglages;
create policy tdn_reglages_lecture on tdn_reglages for select using (true);
EOF_PN_FICHIER
echo "  ✓ supabase/pere_noel_v4.sql"

git add -A && git commit -m "Menu : Trésors de Noël affiché uniquement si le module est actif" && git push
vercel --prod
echo "Puis exécuter supabase/pere_noel_v4.sql dans Supabase (lecture publique de tdn_reglages)."
