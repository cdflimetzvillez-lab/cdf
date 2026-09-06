import Link from 'next/link';
import type { Metadata } from 'next';
import { createClient } from '@/lib/supabase/server';
import { configRoue, getWheelConfig } from '@/lib/roue/db';
import { createAdminClient } from '@/lib/supabase/admin';
import type { SiteSettings } from '@/lib/types';
import type { LotRoue } from '@/lib/roue/types';

export const metadata: Metadata = { title: 'Règlement de la Roue de la Rentrée · Comité des Fêtes de Limetz-Villez' };
export const revalidate = 300;

const date = (iso: string | null) => iso ? new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long', timeStyle: 'short', timeZone: 'Europe/Paris' }).format(new Date(iso)) : '—';

export default async function PageReglementRoue() {
  const supabase = await createClient();
  const [{ data: settings }, module, { data: lots }] = await Promise.all([
    supabase.from('site_settings').select('*').eq('id', 1).single(),
    getWheelConfig(),
    createAdminClient().from('roue_lots').select('*').eq('actif', true).order('position'),
  ]);
  const s = settings as SiteSettings;
  const c = configRoue(module);
  const L = (lots ?? []) as LotRoue[];

  return (
    <>
      <Link href="/" className="crumb">← Accueil</Link>
      <main className="wrap" style={{ padding: '6rem 2rem 4rem', maxWidth: 820 }}>
        <span className="kicker mono">Jeu gratuit sans obligation d&apos;achat</span>
        <h1 style={{ fontSize: 'clamp(2.4rem,7vw,4.5rem)', lineHeight: .95, margin: '1rem 0 .6rem' }}>Règlement<br />{c.titre}</h1>
        <p style={{ color: '#4a444a', fontWeight: 600, marginBottom: '2.5rem' }}>Du {date(module?.start_date ?? null)} au {date(module?.end_date ?? null)}</p>

        <div className="reglement">
          <h2>Article 1 · Organisateur</h2>
          <p>Le jeu « {c.titre} » est organisé par le Comité des Fêtes de Limetz-Villez, association loi 1901, {s.adresse}, joignable à l&apos;adresse {s.email_contact} (ci-après « l&apos;Organisateur »).</p>

          <h2>Article 2 · Durée</h2>
          <p>Le jeu se déroule du {date(module?.start_date ?? null)} au {date(module?.end_date ?? null)} (heure de Paris). L&apos;Organisateur se réserve le droit d&apos;écourter, de prolonger, de suspendre ou d&apos;annuler le jeu à tout moment, notamment en cas de force majeure, sans que sa responsabilité puisse être engagée.</p>

          <h2>Article 3 · Conditions de participation</h2>
          <p>Le jeu est gratuit et sans obligation d&apos;achat. Il est ouvert à toute personne physique majeure, ou mineure avec l&apos;accord d&apos;un représentant légal, résidant en France métropolitaine. Les membres du bureau de l&apos;Organisateur ne peuvent pas participer.</p>
          <p>La participation est limitée à {c.participations_par_jour > 1 ? `${c.participations_par_jour} tours` : 'un tour'} par jour et par personne, sur l&apos;ensemble de la durée du jeu. Toute tentative de contournement de cette limite (appareils ou navigateurs multiples, suppression des cookies, automatisation) entraîne la nullité des participations concernées.</p>

          <h2>Article 4 · Déroulement</h2>
          <p>Le jeu est accessible sur la page d&apos;accueil du site {process.env.NEXT_PUBLIC_SITE_URL ?? 'cdf-limetzvillez.fr'}. Le participant lance la roue en cliquant ou en touchant celle-ci. Le résultat, gagnant ou perdant, est déterminé par tirage au sort informatique au moment du lancement, indépendamment de l&apos;animation affichée. Un tour gagnant attribue l&apos;un des lots encore disponibles.</p>
          <p>En cas de gain, un code personnel est affiché. Le participant renseigne ses nom, prénom, adresse e-mail et numéro de téléphone afin de permettre la remise du lot. Ces informations sont indispensables : un gain non réclamé ne peut être attribué.</p>

          <h2>Article 5 · Dotations</h2>
          <p>Les lots mis en jeu, dans la limite des stocks disponibles, sont les suivants :</p>
          <ul>
            {L.map((l) => <li key={l.id}><b>{l.nom}</b>{l.description && ` · ${l.description}`} ({l.stock} exemplaire{l.stock > 1 ? 's' : ''})</li>)}
            {L.length === 0 && <li>Liste des lots à venir.</li>}
          </ul>
          <p>Les lots ne peuvent être échangés contre leur valeur en espèces ni contre un autre lot. L&apos;Organisateur se réserve la possibilité de remplacer un lot par un lot de valeur équivalente en cas d&apos;indisponibilité.</p>

          <h2>Article 6 · Remise des lots</h2>
          <p>{c.message_gagne} Les lots sont à retirer sur présentation du code gagnant et d&apos;une pièce d&apos;identité, dans un délai de trente jours après la fin du jeu. Passé ce délai, le lot reste acquis à l&apos;Organisateur.</p>

          <h2>Article 7 · Données personnelles</h2>
          <p>Les données collectées (nom, prénom, e-mail, téléphone, identifiant technique de participation) sont utilisées uniquement pour la gestion du jeu et la remise des lots. Elles sont conservées trois mois après la fin du jeu puis supprimées. Conformément au RGPD, vous disposez d&apos;un droit d&apos;accès, de rectification et de suppression en écrivant à {s.email_contact}.</p>
          <p>Un cookie technique, sans finalité publicitaire, est déposé pour limiter le nombre de participations quotidiennes.</p>

          <h2>Article 8 · Responsabilité</h2>
          <p>L&apos;Organisateur ne saurait être tenu responsable d&apos;un dysfonctionnement du réseau Internet, du terminal du participant ou de toute autre cause empêchant la participation. Toute participation frauduleuse ou contraire au présent règlement entraîne l&apos;exclusion du participant.</p>

          <h2>Article 9 · Acceptation</h2>
          <p>La participation au jeu implique l&apos;acceptation pleine et entière du présent règlement, disponible sur cette page pendant toute la durée du jeu. Toute question relative à son interprétation est tranchée par l&apos;Organisateur.</p>
        </div>

        <p style={{ marginTop: '3rem' }}><Link href="/" className="btn btn-y">Retour à l&apos;accueil</Link></p>
      </main>
    </>
  );
}
