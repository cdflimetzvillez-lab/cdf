import Link from 'next/link';
import { createClient } from '@/lib/supabase/server';
import MenuButton from '@/components/MenuButton';
import RetourHaut from '@/components/RetourHaut';
import Marquee from '@/components/Marquee';
import Footer from '@/components/Footer';
import RoueRentree from '@/components/roue/RoueRentree';
import { configRoue, getWheelConfig, roueVisible } from '@/lib/roue/db';
import { dateCourte, dateLongue, horaires, periode, texteSur } from '@/lib/format';
import type { SiteSettings, Stat, Evenement } from '@/lib/types';

export const revalidate = 60;

export default async function Home() {
  const supabase = await createClient();

  const [{ data: settings }, { data: stats }, { data: evenements }, wheelConfig] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(),
    supabase.from('stats').select('*').order('position'),
    supabase.from('evenements').select('*').eq('publie', true).order('position'),
    getWheelConfig(),
  ]);
  // Module événementiel : rendu côté serveur uniquement si actif et dans la période.
  const showWheel = roueVisible(wheelConfig);

  const s = settings as SiteSettings;
  const evts = (evenements ?? []) as Evenement[];

  return (
    <>
      <MenuButton />
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
