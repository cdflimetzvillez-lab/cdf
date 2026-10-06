import type { ReactNode } from 'react';
import Neige from './Neige';

/**
 * Écran « mission accomplie » : le lutin farceur fait une farce différente à chaque mission
 * (12 farces, attribuées dans l'ordre des missions, puis on recommence), éclate de rire,
 * et le texte avec le bouton « Continuer » arrivent ensuite.
 *
 * Tout est en SVG + CSS (bloc .tdn-farce de tresors.css, une classe .f1 … .f12 par farce).
 * La scène est dessinée dans un repère de 240 × 220 dont l'origine est aux pieds du lutin (sol = y 0).
 * Pour faire pivoter un élément autour d'un point, on l'enferme dans un groupe translaté sur ce point.
 */

const PEAU = '#f2cfa8';
const VERT = '#35a876';
const VERT_OMBRE = '#2a8b61';
const BORDEAUX = '#b5384e';
const CREME = '#fbf7ef';
const BRUN = '#3a2416';
const NUIT = '#0a1432';
const OR = '#e5c07b';
const NEIGE = '#f4f7ff';
const NEIGE_OMBRE = '#cfdcf7';
const LUEUR = 'url(#tdnf-lueur)';
const ECLAT = 'M0 -5Q.8 -.8 5 0Q.8 .8 0 5Q-.8 .8 -5 0Q-.8 -.8 0 -5Z';
const LAMPIONS = ['#ffd98a', '#ff7f8f', '#9cc2ff', '#8fe0b4'];

/* ------------------------------------------------------------------ le lutin */

/** Un bras droit : de l'épaule (origine du groupe) à la main. sens = 1 à droite, -1 à gauche. */
function Bras({ sens = 1, x, y }: { sens?: 1 | -1; x: number; y: number }) {
  return (
    <>
      <path d={`M0 0L${sens * x} ${y}`} fill="none" stroke={VERT} strokeWidth={11} strokeLinecap="round" />
      <circle cx={sens * x * 1.12} cy={y * 1.12} r={6.5} fill={PEAU} />
    </>
  );
}
const brasBas = (sens: 1 | -1 = 1) => <Bras sens={sens} x={18} y={21} />;
const brasLeve = (sens: 1 | -1 = 1) => <Bras sens={sens} x={19} y={-25} />;

/** Le lutin, pieds à l'origine. Les bras sont remplaçables ; « dessus » se dessine par-dessus lui. */
function Lutin({ brasD, brasG, dessus }: { brasD?: ReactNode; brasG?: ReactNode; dessus?: ReactNode }) {
  return (
    <g className="lf-rire">
      {/* jambes et souliers */}
      <rect x={-17} y={-34} width={11} height={30} fill={BORDEAUX} />
      <rect x={6} y={-34} width={11} height={30} fill={BORDEAUX} />
      <path d="M-17 -24h11M-17 -14h11M6 -24h11M6 -14h11" stroke={CREME} strokeWidth={3.4} />
      <path d="M-5 0Q-6 -10 -15 -9Q-27 -9 -30 -2Q-33 -8 -28 -11Q-34 -12 -33 -5Q-32 0 -24 0Z" fill={BRUN} />
      <path d="M5 0Q6 -10 15 -9Q27 -9 30 -2Q33 -8 28 -11Q34 -12 33 -5Q32 0 24 0Z" fill={BRUN} />
      <circle cx={-31.5} cy={-11.5} r={2.6} fill={OR} />
      <circle cx={31.5} cy={-11.5} r={2.6} fill={OR} />

      {/* bras gauche (par défaut : poing sur la hanche) */}
      <g transform="translate(-21 -72)">
        <g className="lf-bras-g">
          {brasG ?? (
            <>
              <path d="M1 0Q-19 10 -6 25" fill="none" stroke={VERT_OMBRE} strokeWidth={11} strokeLinecap="round" />
              <circle cx={-5} cy={27} r={6.5} fill={PEAU} />
            </>
          )}
        </g>
      </g>

      {/* tunique, ceinture, col */}
      <path d="M-29 -30L-21 -79Q0 -88 21 -79L29 -30Q21 -22 14 -30Q7 -22 0 -30Q-7 -22 -14 -30Q-21 -22 -29 -30Z" fill={VERT} />
      <path d="M9 -84Q16 -82 21 -79L29 -30Q21 -22 14 -30Z" fill={VERT_OMBRE} opacity={0.55} />
      <rect x={-25.5} y={-53} width={51} height={9} fill="#20150f" />
      <rect x={-7} y={-55.5} width={14} height={14} rx={2.4} fill={OR} />
      <rect x={-3.4} y={-51.9} width={6.8} height={6.8} rx={1} fill="#20150f" />
      <path d="M-19 -81L-12 -69L-6 -78L0 -68L6 -78L12 -69L19 -81Q0 -89 -19 -81Z" fill={BORDEAUX} />

      {/* bras droit */}
      <g transform="translate(21 -72)">
        <g className="lf-bras-d">{brasD ?? brasBas()}</g>
      </g>

      {/* tête (pivote autour du cou) */}
      <g transform="translate(0 -80)">
        <g className="lf-tete">
          <g transform="translate(0 80)">
            <path d="M-17 -103L-37 -113L-18 -91Z" fill={PEAU} />
            <path d="M17 -103L37 -113L18 -91Z" fill={PEAU} />
            <path d="M-19 -101L-31 -108L-20 -95Z" fill="#e3b58c" />
            <path d="M19 -101L31 -108L20 -95Z" fill="#e3b58c" />
            <circle cx={0} cy={-98} r={20.5} fill={PEAU} />
            <circle cx={-12.5} cy={-91.5} r={4.4} fill="#e88a8a" opacity={0.6} />
            <circle cx={12.5} cy={-91.5} r={4.4} fill="#e88a8a" opacity={0.6} />
            <circle cx={0} cy={-94.5} r={2.7} fill="#e3a984" />

            {/* avant la farce : regard malicieux, sourire en coin */}
            <g className="lf-avant">
              <circle cx={-7.5} cy={-101} r={2.8} fill="#2a1a12" />
              <circle cx={7.5} cy={-101} r={2.8} fill="#2a1a12" />
              <circle cx={-6.6} cy={-102} r={0.9} fill="#fff" />
              <circle cx={8.4} cy={-102} r={0.9} fill="#fff" />
              <path d="M-12 -107.5L-4 -105.5M4 -108.5L12 -106" stroke="#8a5a34" strokeWidth={1.8} strokeLinecap="round" />
              <path d="M-5 -88Q2 -84 8 -90" fill="none" stroke="#8a3b2a" strokeWidth={1.9} strokeLinecap="round" />
            </g>
            {/* la grimace (farce n° 8) : un œil fermé, la langue tirée */}
            <g className="lf-grimace">
              <circle cx={-7.5} cy={-101} r={3.4} fill="#2a1a12" />
              <circle cx={-6.4} cy={-102.2} r={1.1} fill="#fff" />
              <path d="M3.5 -103.5L11.5 -99M3.5 -99L11.5 -103.5" stroke="#2a1a12" strokeWidth={2.2} strokeLinecap="round" />
              <path d="M-12.5 -109L-4 -106M4 -106L12.5 -109" stroke="#8a5a34" strokeWidth={1.8} strokeLinecap="round" />
              <path d="M-8.5 -89.5Q0 -84 8.5 -89.5Q0 -86 -8.5 -89.5Z" fill="#6b1f2a" stroke="#6b1f2a" strokeWidth={1.4} strokeLinejoin="round" />
              <g transform="translate(0 -87)">
                <g className="lf-langue">
                  <path d="M-4.6 0Q-5.4 12 0 13.5Q5.4 12 4.6 0Z" fill="#e8667c" />
                  <path d="M0 1.5V9" stroke="#c2455c" strokeWidth={1} strokeLinecap="round" />
                </g>
              </g>
            </g>
            {/* après : yeux plissés, grand rire */}
            <g className="lf-apres">
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
      {dessus}
    </g>
  );
}

/* ------------------------------------------------------------------ accessoires communs */

/** Neige au sol. Dessinée après le lutin, elle cache ses pieds : il surgit de derrière. */
function Congere() {
  return (
    <>
      <ellipse cx={0} cy={26} rx={132} ry={30} fill="url(#tdnf-sol-ombre)" />
      <ellipse cx={-8} cy={25} rx={128} ry={27} fill="url(#tdnf-sol)" />
    </>
  );
}

/** Ce qui se cache derrière la congère : coupé au ras de la neige, on ne le voit jamais en dessous. */
function Derriere({ children }: { children: ReactNode }) {
  return <g clipPath="url(#tdnf-sol-coupe)">{children}</g>;
}

/** Collines enneigées au loin : donnent de la profondeur quand le lutin arrive de loin. */
function Collines() {
  return (
    <>
      <ellipse cx={0} cy={-30} rx={175} ry={36} fill="#1c2f6b" />
      <ellipse cx={0} cy={-2} rx={185} ry={34} fill="#27408a" />
    </>
  );
}

/** Gerbe d'étoiles ou de flocons qui partent d'un point (animation .lf-eclat, réglée par farce). */
function Gerbe({ x, y, n = 8, couleurs = ['#ffe9ad'], rond = false, depart = 0 }: { x: number; y: number; n?: number; couleurs?: string[]; rond?: boolean; depart?: number }) {
  return (
    <>
      {Array.from({ length: n }, (_, i) => (
        <g key={i} transform={`translate(${x} ${y}) rotate(${depart + (i * 360) / n})`}>
          {rond ? <circle className="lf-eclat" r={3 + (i % 3)} fill={couleurs[i % couleurs.length]} /> : <path className="lf-eclat" d={ECLAT} fill={couleurs[i % couleurs.length]} />}
        </g>
      ))}
    </>
  );
}

/** Points répartis sur une courbe (pour poser des ampoules sur un fil). */
function surCourbe(a: [number, number], c: [number, number], b: [number, number], n: number): [number, number][] {
  return Array.from({ length: n }, (_, i) => {
    const t = (i + 0.5) / n;
    return [
      Math.round(((1 - t) ** 2 * a[0] + 2 * t * (1 - t) * c[0] + t * t * b[0]) * 10) / 10,
      Math.round(((1 - t) ** 2 * a[1] + 2 * t * (1 - t) * c[1] + t * t * b[1]) * 10) / 10,
    ];
  });
}

/* ------------------------------------------------------------------ les 12 farces */

type Farce = { replique: string; scene: ReactNode; ecran?: ReactNode };

/** 1. La boule de neige : il la lance sur l'écran. */
const bouleDeNeige: Farce = {
  replique: 'Hi hi hi !',
  scene: (
    <>
      <Derriere>
        <g className="lf-surgit">
          <Lutin brasD={<>{brasBas()}<g className="f1-main"><circle cx={26} cy={28} r={8.5} fill={NEIGE} /><path d="M20 32Q26 38 33 32" fill="none" stroke={NEIGE_OMBRE} strokeWidth={2} strokeLinecap="round" /></g></>} />
        </g>
      </Derriere>
      <g transform="translate(47 -44)"><circle className="f1-boule" r={8.5} fill={NEIGE} /></g>
      <Congere />
    </>
  ),
  ecran: (
    <svg className="tdn-farce-splat" viewBox="0 0 200 220" aria-hidden="true">
      <path d="M100 18Q117 44 143 28Q140 60 174 60Q151 84 182 108Q149 113 158 148Q128 133 113 170Q98 139 71 164Q72 131 34 140Q56 111 20 92Q56 82 43 46Q76 58 100 18Z" fill={NEIGE} />
      <path d="M113 170Q98 139 71 164Q72 131 34 140Q60 128 78 140Q98 126 113 170Z" fill={NEIGE_OMBRE} opacity={0.7} />
      <path d="M86 150q4 34 -2 52a7 7 0 0 0 14 0q-5 -20 -2 -52zM132 140q3 22 -1 34a5.5 5.5 0 0 0 11 0q-4 -14 -2 -34zM56 132q2 16 -1 24a4.5 4.5 0 0 0 9 0q-3 -10 -1 -24z" fill={NEIGE} />
      <circle cx={22} cy={46} r={6} fill={NEIGE} /><circle cx={180} cy={38} r={4.5} fill={NEIGE} /><circle cx={190} cy={150} r={5} fill={NEIGE} />
      <circle cx={12} cy={132} r={3.5} fill={NEIGE} /><circle cx={150} cy={12} r={3.5} fill={NEIGE} /><circle cx={60} cy={14} r={4} fill={NEIGE} />
    </svg>
  ),
};

/** 2. Coucou : la tête à gauche, puis à droite, puis il surgit au milieu. */
const coucou: Farce = {
  replique: 'Coucou !',
  scene: (
    <>
      <Derriere><g className="f2-cache"><Lutin /></g></Derriere>
      <Congere />
    </>
  ),
};

/** 3. La tête en bas : suspendu par les pieds à une guirlande, il se balance. */
const teteEnBas: Farce = {
  replique: 'Ça va en bas ?',
  scene: (
    <>
      <Congere />
      <path d="M-125 -182Q0 -150 125 -182" fill="none" stroke={NUIT} strokeWidth={1.8} />
      {surCourbe([-125, -182], [0, -150], [125, -182], 9).map(([x, y], i) => (
        <g key={i}>
          <circle cx={x} cy={y + 4} r={7} fill={LUEUR} />
          <circle className={`lf-guir lf-d${(i % 3) + 1}`} cx={x} cy={y + 4} r={3.4} fill={LAMPIONS[i % 4]} />
        </g>
      ))}
      <g transform="translate(0 -166)">
        <g className="f3-chute">
          <g className="f3-balance">
            <g transform="rotate(180) scale(.9)"><Lutin brasD={brasLeve()} brasG={brasLeve(-1)} /></g>
          </g>
        </g>
      </g>
    </>
  ),
};

/** 4. Le cadeau surprise : le couvercle saute, le lutin jaillit comme un diable à ressort. */
const cadeau: Farce = {
  replique: 'Surprise !',
  scene: (
    <>
      <Congere />
      <g clipPath="url(#tdnf-boite)">
        <g className="f4-ressort"><g transform="scale(.9)"><Lutin brasD={brasLeve()} brasG={brasLeve(-1)} /></g></g>
      </g>
      <g className="f4-boite">
        <ellipse cx={0} cy={1} rx={46} ry={6} fill="#040a1c" opacity={0.3} />
        <rect x={-36} y={-50} width={72} height={50} fill={BORDEAUX} />
        <rect x={20} y={-50} width={16} height={50} fill="#8f2a3d" opacity={0.6} />
        <rect x={-6.5} y={-50} width={13} height={50} fill={OR} />
        <g transform="translate(0 -56)">
          <g className="f4-couvercle">
            <rect x={-41} y={-7} width={82} height={14} rx={3} fill="#cf4a62" />
            <rect x={-6.5} y={-7} width={13} height={14} fill={OR} />
            <path d="M0 -7Q-20 -26 -24 -12Q-22 -4 0 -7ZM0 -7Q20 -26 24 -12Q22 -4 0 -7Z" fill={OR} />
            <circle cx={0} cy={-8} r={4} fill="#c99a3b" />
          </g>
        </g>
      </g>
      <Gerbe x={0} y={-58} n={10} couleurs={['#ffe9ad', '#ff7f8f', '#9cc2ff']} />
    </>
  ),
};

/** 5. La glissade : il traverse sur une plaque de glace, part en vrille et finit les quatre fers en l'air. */
const glissade: Farce = {
  replique: 'Même pas mal !',
  scene: (
    <>
      <Congere />
      <ellipse cx={6} cy={3} rx={104} ry={8} fill="#bfe0ff" opacity={0.6} />
      <path d="M-60 2H-20M10 5H52" stroke="#fff" strokeWidth={1.6} strokeLinecap="round" opacity={0.8} />
      <g className="f5-glisse">
        <g transform="translate(0 -34)">
          <g className="f5-chute">
            <g transform="translate(0 34)"><Lutin brasD={brasLeve()} brasG={brasLeve(-1)} /></g>
          </g>
        </g>
      </g>
      <Gerbe x={44} y={-4} n={7} couleurs={[NEIGE, NEIGE_OMBRE]} rond depart={-90} />
    </>
  ),
};

/** 6. Le grelot : il secoue une grosse cloche et tout l'écran tremble. */
const grelot: Farce = {
  replique: 'Ding ding !',
  scene: (
    <>
      <Derriere>
      <g className="lf-surgit">
        <Lutin brasD={(
          <>
            <Bras x={27} y={-4} />
            <rect x={27.5} y={-2} width={5.5} height={9} rx={2} fill="#6a3b1f" />
            <path d="M30 6Q18 8 17 23Q15.5 29 12 31H48Q44.5 29 43 23Q42 8 30 6Z" fill={OR} />
            <path d="M24 11Q20 15 20 24" fill="none" stroke="#fff1c9" strokeWidth={2} strokeLinecap="round" />
            <rect x={11} y={30} width={38} height={4.5} rx={2.2} fill="#c99a3b" />
            <circle cx={30} cy={37} r={3.8} fill="#a8782a" />
          </>
        )} />
      </g>
      </Derriere>
      {[0, 1, 2].map((i) => (
        <path key={i} className={`f6-onde lf-d${i + 1}`} d={`M${84 + i * 11} ${-64 - i * 4}Q${96 + i * 13} -44 ${84 + i * 11} ${-24 + i * 4}`} fill="none" stroke="#ffe9ad" strokeWidth={3} strokeLinecap="round" />
      ))}
      <Congere />
    </>
  ),
};

/** 7. La guirlande : emmêlé dedans, il se débat… et elle s'allume d'un coup. */
const FILS: [[number, number], [number, number], [number, number]][] = [
  [[-31, -32], [0, -42], [31, -50]],
  [[-29, -57], [0, -64], [30, -77]],
  [[-25, -121], [0, -128], [27, -136]],
];
const AMPOULES = FILS.flatMap(([a, c, b]) => surCourbe(a, c, b, 4));
const guirlande: Farce = {
  replique: 'Tadam !',
  scene: (
    <>
      <Derriere>
      <g className="lf-surgit">
        <g className="f7-gigote">
          <Lutin dessus={(
            <>
              <path d="M-31 -32Q0 -42 31 -50M-29 -57Q0 -64 30 -77M-25 -121Q0 -128 27 -136M-31 -32Q-46 -20 -40 -4M27 -136Q46 -128 46 -108" fill="none" stroke="#06101f" strokeWidth={2.8} strokeLinecap="round" />
              {AMPOULES.map(([x, y], i) => <circle key={i} cx={x} cy={y + 3} r={4.2} fill="#7f8db3" stroke="#06101f" strokeWidth={1} />)}
              <g className="f7-allume">
                {AMPOULES.map(([x, y], i) => (
                  <g key={i}>
                    <circle cx={x} cy={y + 3} r={15} fill={LUEUR} />
                    <circle cx={x} cy={y + 3} r={4.2} fill="#fff" />
                    <circle className={`lf-guir lf-d${(i % 3) + 1}`} cx={x} cy={y + 3} r={4.2} fill={LAMPIONS[i % 4]} />
                  </g>
                ))}
              </g>
            </>
          )} />
        </g>
      </g>
      </Derriere>
      <Congere />
    </>
  ),
};

/** 8. La grimace : il fonce vers l'écran, tire la langue en gros plan, puis recule. */
const grimace: Farce = {
  replique: 'Nananère !',
  scene: (
    <>
      <Collines />
      <Congere />
      <g transform="translate(0 -98)">
        <g className="f8-zoom">
          <g className="f8-secoue">
            <g transform="translate(0 98)"><Lutin /></g>
          </g>
        </g>
      </g>
    </>
  ),
};

/** 9. La luge : deux passages en trombe au loin, puis il freine devant le joueur. */
const luge: Farce = {
  replique: 'Youhou !',
  scene: (
    <>
      <Collines />
      <Congere />
      <g className="f9-course">
        <g className="f9-penche">
          <path d="M-40 1Q-48 -8 -37 -9M-37 1H36Q47 1 45 -9" fill="none" stroke={NEIGE_OMBRE} strokeWidth={3} strokeLinecap="round" />
          <path d="M-26 -8V0M26 -8V0" stroke="#6a3b1f" strokeWidth={3} />
          <rect x={-36} y={-13} width={72} height={6} rx={3} fill="#8a5a2b" />
          <g transform="translate(0 -12)"><Lutin brasD={brasLeve()} /></g>
        </g>
      </g>
      <Gerbe x={-38} y={-4} n={7} couleurs={[NEIGE, NEIGE_OMBRE]} rond depart={-150} />
    </>
  ),
};

/** 10. Le bonhomme de neige : la tête se soulève… le lutin était caché dedans. */
const bonhomme: Farce = {
  replique: 'C’était moi !',
  scene: (
    <>
      <Derriere><g className="f10-sort"><g transform="scale(.72)"><Lutin /></g></g></Derriere>
      <ellipse cx={0} cy={2} rx={54} ry={7} fill="#040a1c" opacity={0.25} />
      <circle cx={0} cy={-36} r={42} fill={NEIGE} />
      <path d="M-38 -18A42 42 0 0 0 38 -18A46 46 0 0 1 -38 -18Z" fill={NEIGE_OMBRE} opacity={0.7} />
      <path d="M-26 -98L-58 -118M-46 -110L-52 -98M-50 -113L-60 -108M26 -98L58 -118M46 -110L52 -98M50 -113L60 -108" stroke="#6a3b1f" strokeWidth={2.6} strokeLinecap="round" fill="none" />
      <circle cx={0} cy={-92} r={29} fill={NEIGE} />
      <path d="M-26 -80A29 29 0 0 0 26 -80A32 32 0 0 1 -26 -80Z" fill={NEIGE_OMBRE} opacity={0.7} />
      <circle cx={0} cy={-100} r={2.6} fill={NUIT} /><circle cx={0} cy={-88} r={2.6} fill={NUIT} /><circle cx={0} cy={-76} r={2.6} fill={NUIT} />
      <path d="M-20 -113Q0 -105 20 -113L18 -120Q0 -113 -18 -120Z" fill={BORDEAUX} />
      <path d="M12 -113L17 -92L25 -94L20 -115Z" fill={BORDEAUX} />
      <g transform="translate(0 -131)">
        <g className="f10-tete">
          <circle r={21} fill={NEIGE} />
          <circle cx={-7} cy={-4} r={2.4} fill={NUIT} /><circle cx={7} cy={-4} r={2.4} fill={NUIT} />
          <path d="M0 2L17 5L0 8Z" fill="#f08a3c" />
          <path d="M-9 11Q0 16 9 11" fill="none" stroke={NUIT} strokeWidth={1.6} strokeLinecap="round" strokeDasharray="1.5 3" />
          <rect x={-19} y={-21} width={38} height={4.5} rx={2} fill={NUIT} />
          <rect x={-12} y={-39} width={24} height={19} fill={NUIT} />
          <rect x={-12} y={-27} width={24} height={4} fill={BORDEAUX} />
        </g>
      </g>
      <Congere />
    </>
  ),
};

/** 11. L'avalanche : il secoue le sapin, toute la neige lui tombe dessus, il ressort en s'ébrouant. */
const ETAGES: [number, number, number, string][] = [[96, -12, -66, '#123d31'], [80, -50, -100, '#16493a'], [62, -86, -130, '#1a5644'], [40, -118, -158, '#1f634e']];
const avalanche: Farce = {
  replique: 'Brrr… encore !',
  scene: (
    <>
      <g transform="translate(46 0)">
        <g className="f11-arbre">
          <rect x={-6} y={-14} width={12} height={16} fill="#2c190c" />
          {ETAGES.map(([w, bas, haut, couleur]) => <polygon key={w} points={`0,${haut} ${-w / 2},${bas} ${w / 2},${bas}`} fill={couleur} />)}
          <g className="f11-charge">
            {ETAGES.map(([w, bas, haut]) => (
              <path key={w} d={`M0 ${haut - 3}L${-w * 0.36} ${bas - (bas - haut) * 0.28}Q${-w * 0.18} ${bas - (bas - haut) * 0.5} 0 ${bas - (bas - haut) * 0.36}Q${w * 0.18} ${bas - (bas - haut) * 0.5} ${w * 0.36} ${bas - (bas - haut) * 0.28}Z`} fill={NEIGE} />
            ))}
          </g>
        </g>
      </g>
      <g transform="translate(-30 0)">
        <Derriere>
        <g className="lf-surgit">
          <g className="f11-ebroue">
            <g transform="scale(.82)">
              <Lutin brasD={<Bras x={27} y={-6} />} dessus={<g className="f11-reste"><path d="M-22 -112Q-6 -158 18 -152Q34 -150 36 -138Q20 -140 6 -132Q-8 -124 -22 -112Z" fill={NEIGE} /><ellipse cx={-22} cy={-79} rx={9} ry={4} fill={NEIGE} /><ellipse cx={21} cy={-80} rx={8} ry={3.6} fill={NEIGE} /></g>} />
            </g>
          </g>
        </g>
        </Derriere>
        <g className="f11-tas">
          <path d="M-64 0Q-70 -62 -42 -104Q-20 -142 8 -140Q42 -134 54 -84Q66 -40 62 0Z" fill={NEIGE} />
          <path d="M10 -140Q42 -134 54 -84Q66 -40 62 0H34Q46 -60 10 -140Z" fill={NEIGE_OMBRE} opacity={0.75} />
        </g>
        <Gerbe x={0} y={-60} n={9} couleurs={[NEIGE, NEIGE_OMBRE]} rond />
      </g>
      <Congere />
    </>
  ),
};

/** 12. Le feu d'artifice : la fusée fait pschitt… puis décolle et explose en étoiles. */
const BOUQUETS: [number, number, string[]][] = [[18, -140, ['#ffe29a', '#ffd98a']], [-66, -128, ['#ff7f8f', '#ffd0d6']], [78, -112, ['#9cc2ff', '#dbe8ff']]];
const feuDArtifice: Farce = {
  replique: 'Et boum !',
  scene: (
    <>
      {BOUQUETS.map(([x, y, couleurs], k) => (
        <g key={k} className={`f12-bouquet f12-b${k + 1}`}>
          <Gerbe x={x} y={y} n={12} couleurs={couleurs} />
        </g>
      ))}
      {[[-92, -150], [-20, -168], [52, -160], [100, -138], [-56, -104], [84, -76]].map(([x, y], i) => (
        <g key={i} transform={`translate(${x} ${y})`}><path className={`f12-scint lf-d${(i % 3) + 1}`} d={ECLAT} fill={['#ffe9ad', '#ffd0d6', '#dbe8ff'][i % 3]} /></g>
      ))}
      <g transform="translate(-40 0)">
        <Derriere><g className="lf-surgit"><g transform="scale(.86)"><Lutin brasG={brasBas(-1)} /></g></g></Derriere>
      </g>
      <g transform="translate(50 -2)">
        <g className="f12-fusee">
          <path d="M0 0V-46" stroke="#8a5a2b" strokeWidth={3} strokeLinecap="round" />
          <path className="f12-flamme" d="M-6 -40Q0 -8 6 -40Q0 -30 -6 -40Z" fill="#ffb347" />
          <rect x={-7.5} y={-72} width={15} height={32} rx={3} fill="#d2455a" />
          <rect x={-7.5} y={-62} width={15} height={6} fill={CREME} />
          <path d="M-10 -72L0 -93L10 -72Z" fill={OR} />
          <path d="M-7.5 -44Q-17 -42 -15 -31" fill="none" stroke="#6a3b1f" strokeWidth={1.6} strokeLinecap="round" />
          <g transform="translate(-15 -30)"><path className="f12-etincelle" d={ECLAT} fill="#ffd98a" /></g>
        </g>
      </g>
      {[0, 1, 2].map((i) => <g key={i} transform={`translate(${38 + i * 6} ${-34 - i * 5})`}><circle className={`f12-fumee lf-d${i + 1}`} r={6 + i * 1.5} fill="#dfe8ff" /></g>)}
      <Congere />
    </>
  ),
};

const FARCES: Farce[] = [bouleDeNeige, coucou, teteEnBas, cadeau, glissade, grelot, guirlande, grimace, luge, bonhomme, avalanche, feuDArtifice];

type Props = {
  /** Numéro de la mission : choisit la farce (mission 1 = farce 1, etc.). */
  numero: number;
  /** Prénoms des participants pour qui la mission vient d'être validée. */
  validePour: string[];
  /** C'était la dernière mission. */
  dernier: boolean;
  onContinuer: () => void;
};

export default function LutinFarceur({ numero, validePour, dernier, onContinuer }: Props) {
  const rang = (((Math.max(1, Math.round(numero)) - 1) % FARCES.length) + FARCES.length) % FARCES.length;
  const farce = FARCES[rang];
  return (
    <section className={`tdn-farce f${rang + 1}`}>
      <div className="tdn-etoiles" aria-hidden="true" />
      <Neige flocons={22} />

      <div className="tdn-farce-inner">
        <div className="tdn-farce-scene" aria-hidden="true">
          <svg className="tdn-farce-svg" viewBox="0 0 240 220">
            <defs>
              <radialGradient id="tdnf-lueur"><stop offset="0" stopColor="#ffd98a" stopOpacity=".55" /><stop offset=".5" stopColor="#f4c76a" stopOpacity=".2" /><stop offset="1" stopColor="#f4c76a" stopOpacity="0" /></radialGradient>
              <linearGradient id="tdnf-sol" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={NEIGE} /><stop offset=".3" stopColor={NEIGE} /><stop offset=".62" stopColor={NEIGE} stopOpacity="0" /></linearGradient>
              <linearGradient id="tdnf-sol-ombre" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={NEIGE_OMBRE} /><stop offset=".3" stopColor={NEIGE_OMBRE} /><stop offset=".6" stopColor={NEIGE_OMBRE} stopOpacity="0" /></linearGradient>
              <clipPath id="tdnf-sol-coupe"><rect x={-260} y={-260} width={520} height={270} /></clipPath>
              <clipPath id="tdnf-boite"><rect x={-120} y={-190} width={240} height={142} /></clipPath>
            </defs>
            <g transform="translate(120 185)">{farce.scene}</g>
          </svg>
          <span className="tdn-farce-bulle">{farce.replique}</span>
        </div>

        <div className="tdn-farce-texte">
          <h2 className="tdn-titre-fee">Mission accomplie !</h2>
          <p>{dernier ? 'Vous venez de résoudre le dernier mystère…' : 'Vous avez débloqué la mission suivante.'}</p>
          {validePour.length > 0 && <p className="tdn-muted tdn-mini">Validée pour : {validePour.join(', ')}</p>}
          <button type="button" className="tdn-btn tdn-btn-or tdn-btn-large" onClick={onContinuer}>Continuer</button>
        </div>

        {farce.ecran}
      </div>
    </section>
  );
}
