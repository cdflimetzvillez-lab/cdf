import Neige from './Neige';

/**
 * Écran « mission accomplie » : le lutin farceur surgit de derrière une congère, lance une boule de neige
 * qui s'écrase sur l'écran, puis éclate de rire. Le texte et le bouton « Continuer » arrivent ensuite.
 *
 * Tout est en SVG + CSS (bloc .tdn-farce de tresors.css). L'état de repos de chaque élément est l'état final :
 * avec « réduire les animations », on voit directement le lutin hilare, le texte et le bouton.
 */

const REPLIQUES = ['Hi hi hi !', 'Et toc !', 'Bien joué !', 'Attrapé !'];

const PEAU = '#f2cfa8';
const VERT = '#35a876';
const VERT_OMBRE = '#2a8b61';
const BORDEAUX = '#b5384e';
const CREME = '#fbf7ef';
const BRUN = '#3a2416';
const NEIGE = '#f4f7ff';
const NEIGE_OMBRE = '#cfdcf7';

type Props = {
  /** Numéro de la mission : fait varier la réplique du lutin. */
  numero: number;
  /** Prénoms des participants pour qui la mission vient d'être validée. */
  validePour: string[];
  /** C'était la dernière mission. */
  dernier: boolean;
  onContinuer: () => void;
};

export default function LutinFarceur({ numero, validePour, dernier, onContinuer }: Props) {
  return (
    <section className="tdn-farce">
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={22} />

      <div className="tdn-farce-inner">
        <div className="tdn-farce-scene" aria-hidden="true">
          <svg className="tdn-farce-lutin" viewBox="-80 -160 160 176">
            <g className="tdn-farce-corps">
              <g className="tdn-farce-rire">
                {/* jambes et souliers */}
                <rect x={-17} y={-34} width={11} height={30} fill={BORDEAUX} />
                <rect x={6} y={-34} width={11} height={30} fill={BORDEAUX} />
                <path d="M-17 -24h11M-17 -14h11M6 -24h11M6 -14h11" stroke={CREME} strokeWidth={3.4} />
                <path d="M-5 0Q-6 -10 -15 -9Q-27 -9 -30 -2Q-33 -8 -28 -11Q-34 -12 -33 -5Q-32 0 -24 0Z" fill={BRUN} />
                <path d="M5 0Q6 -10 15 -9Q27 -9 30 -2Q33 -8 28 -11Q34 -12 33 -5Q32 0 24 0Z" fill={BRUN} />
                <circle cx={-31.5} cy={-11.5} r={2.6} fill="#e5c07b" />
                <circle cx={31.5} cy={-11.5} r={2.6} fill="#e5c07b" />

                {/* bras gauche, poing sur la hanche */}
                <path d="M-20 -72Q-40 -62 -27 -47" fill="none" stroke={VERT_OMBRE} strokeWidth={11} strokeLinecap="round" />
                <circle cx={-26} cy={-45} r={6.5} fill={PEAU} />

                {/* tunique, ceinture, col */}
                <path d="M-29 -30L-21 -79Q0 -88 21 -79L29 -30Q21 -22 14 -30Q7 -22 0 -30Q-7 -22 -14 -30Q-21 -22 -29 -30Z" fill={VERT} />
                <path d="M9 -84Q16 -82 21 -79L29 -30Q21 -22 14 -30Z" fill={VERT_OMBRE} opacity={0.55} />
                <rect x={-25.5} y={-53} width={51} height={9} fill="#20150f" />
                <rect x={-7} y={-55.5} width={14} height={14} rx={2.4} fill="#e5c07b" />
                <rect x={-3.4} y={-51.9} width={6.8} height={6.8} rx={1} fill="#20150f" />
                <path d="M-19 -81L-12 -69L-6 -78L0 -68L6 -78L12 -69L19 -81Q0 -89 -19 -81Z" fill={BORDEAUX} />

                {/* bras droit : celui qui lance la boule (pivot à l'épaule) */}
                <g className="tdn-farce-bras">
                  <path d="M21 -72L39 -51" fill="none" stroke={VERT} strokeWidth={11} strokeLinecap="round" />
                  <circle cx={41} cy={-49} r={6.5} fill={PEAU} />
                  <g className="tdn-farce-boule-main">
                    <circle cx={47} cy={-44} r={8.5} fill={NEIGE} />
                    <path d="M41 -40Q47 -34 54 -40" fill="none" stroke={NEIGE_OMBRE} strokeWidth={2} strokeLinecap="round" />
                  </g>
                </g>

                {/* tête */}
                <g className="tdn-farce-tete">
                  <path d="M-17 -103L-37 -113L-18 -91Z" fill={PEAU} />
                  <path d="M17 -103L37 -113L18 -91Z" fill={PEAU} />
                  <path d="M-19 -101L-31 -108L-20 -95Z" fill="#e3b58c" />
                  <path d="M19 -101L31 -108L20 -95Z" fill="#e3b58c" />
                  <circle cx={0} cy={-98} r={20.5} fill={PEAU} />
                  <circle cx={-12.5} cy={-91.5} r={4.4} fill="#e88a8a" opacity={0.6} />
                  <circle cx={12.5} cy={-91.5} r={4.4} fill="#e88a8a" opacity={0.6} />
                  <circle cx={0} cy={-94.5} r={2.7} fill="#e3a984" />

                  {/* avant la farce : regard malicieux, sourire en coin */}
                  <g className="tdn-farce-avant">
                    <circle cx={-7.5} cy={-101} r={2.8} fill="#2a1a12" />
                    <circle cx={7.5} cy={-101} r={2.8} fill="#2a1a12" />
                    <circle cx={-6.6} cy={-102} r={0.9} fill="#fff" />
                    <circle cx={8.4} cy={-102} r={0.9} fill="#fff" />
                    <path d="M-12 -107.5L-4 -105.5M4 -108.5L12 -106" stroke="#8a5a34" strokeWidth={1.8} strokeLinecap="round" />
                    <path d="M-5 -88Q2 -84 8 -90" fill="none" stroke="#8a3b2a" strokeWidth={1.9} strokeLinecap="round" />
                  </g>
                  {/* après : yeux plissés, grand rire */}
                  <g className="tdn-farce-apres">
                    <path d="M-11.5 -100Q-7.5 -105.5 -3.5 -100M3.5 -100Q7.5 -105.5 11.5 -100" fill="none" stroke="#2a1a12" strokeWidth={2.2} strokeLinecap="round" />
                    <path d="M-12 -107L-4 -108M4 -108L12 -107" stroke="#8a5a34" strokeWidth={1.8} strokeLinecap="round" />
                    <path d="M-8.5 -90Q0 -75 8.5 -90Z" fill="#6b1f2a" />
                    <path d="M-4.5 -84.2Q0 -87 4.5 -84.2Q0 -79.5 -4.5 -84.2Z" fill="#e88a8a" />
                    <path d="M-8.5 -90Q0 -88 8.5 -90" fill="none" stroke={CREME} strokeWidth={2.2} strokeLinecap="round" />
                  </g>

                  {/* bonnet */}
                  <path d="M-21.5 -108Q-14 -152 20 -148Q36 -146 40 -131Q24 -137 21.5 -108Z" fill={BORDEAUX} />
                  <path d="M6 -148Q30 -150 40 -131Q24 -137 21.5 -108L12 -110Q14 -134 6 -148Z" fill="#8f2a3d" opacity={0.6} />
                  <rect x={-24} y={-115} width={48} height={10.5} rx={5.2} fill={CREME} />
                  <circle cx={41} cy={-129} r={7.4} fill={CREME} />
                </g>
              </g>
            </g>

            {/* congère d'où il surgit */}
            <ellipse cx={0} cy={18} rx={84} ry={25} fill={NEIGE_OMBRE} />
            <ellipse cx={-6} cy={17} rx={80} ry={22} fill={NEIGE} />
          </svg>

          <span className="tdn-farce-boule" />
          <span className="tdn-farce-bulle">{REPLIQUES[numero % REPLIQUES.length]}</span>
        </div>

        <div className="tdn-farce-texte">
          <h2 className="tdn-titre-fee">Mission accomplie !</h2>
          <p>{dernier ? 'Vous venez de résoudre le dernier mystère…' : 'Vous avez débloqué la mission suivante.'}</p>
          {validePour.length > 0 && <p className="tdn-muted tdn-mini">Validée pour : {validePour.join(', ')}</p>}
          <button type="button" className="tdn-btn tdn-btn-or tdn-btn-large" onClick={onContinuer}>Continuer</button>
        </div>

        {/* la boule de neige écrasée sur l'écran */}
        <svg className="tdn-farce-splat" viewBox="0 0 200 220" aria-hidden="true">
          <path d="M100 18Q117 44 143 28Q140 60 174 60Q151 84 182 108Q149 113 158 148Q128 133 113 170Q98 139 71 164Q72 131 34 140Q56 111 20 92Q56 82 43 46Q76 58 100 18Z" fill={NEIGE} />
          <path d="M113 170Q98 139 71 164Q72 131 34 140Q60 128 78 140Q98 126 113 170Z" fill={NEIGE_OMBRE} opacity={0.7} />
          <path d="M86 150q4 34 -2 52a7 7 0 0 0 14 0q-5 -20 -2 -52zM132 140q3 22 -1 34a5.5 5.5 0 0 0 11 0q-4 -14 -2 -34zM56 132q2 16 -1 24a4.5 4.5 0 0 0 9 0q-3 -10 -1 -24z" fill={NEIGE} />
          <circle cx={22} cy={46} r={6} fill={NEIGE} /><circle cx={180} cy={38} r={4.5} fill={NEIGE} /><circle cx={190} cy={150} r={5} fill={NEIGE} />
          <circle cx={12} cy={132} r={3.5} fill={NEIGE} /><circle cx={150} cy={12} r={3.5} fill={NEIGE} /><circle cx={60} cy={14} r={4} fill={NEIGE} />
        </svg>
      </div>
    </section>
  );
}
