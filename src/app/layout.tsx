import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://cdf-limetzvillez.fr'),
  title: 'Comité des Fêtes de Limetz-Villez',
  description:
    "Brocante, fête de la musique, fête des battages, marché de Noël : les rendez-vous du village de Limetz-Villez, toute l'année.",
  openGraph: {
    title: 'Comité des Fêtes de Limetz-Villez',
    description: 'Brocante, fête de la bière, marché de Noël : les rendez-vous du village, toute l\'année.',
    url: '/',
    siteName: 'Comité des Fêtes de Limetz-Villez',
    type: 'website',
    locale: 'fr_FR',
    images: [{
      url: '/og-image.png',
      width: 1200,
      height: 630,
      alt: 'Comité des Fêtes de Limetz-Villez',
    }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Comité des Fêtes de Limetz-Villez',
    description: 'Les rendez-vous du village, toute l\'année.',
    images: ['/og-image.png'],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Anton&family=Bricolage+Grotesque:opsz,wght@12..96,400;12..96,600;12..96,800&family=DM+Mono:wght@400;500&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
