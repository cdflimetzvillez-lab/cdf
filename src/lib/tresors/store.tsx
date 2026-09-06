'use client';
/**
 * État côté client de la démo (compte, participants, progression, clés).
 * Persisté en localStorage pour survivre à la navigation.
 * À remplacer plus tard par Supabase : les actions ci-dessous deviennent des appels API.
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { Cle, Compte, Participant, Progression } from './types';
import { COMPTE_DEMO, EVENEMENT, MISSIONS, PROGRESSION_DEMO } from './mock';

type Etat = {
  compte: Compte;
  progressions: Record<string, Progression>;
  participantActifId: string;
  compteurCle: number;
};

type Ctx = Etat & {
  participantActif: Participant;
  progressionActive: Progression;
  missionCourante: number;          // numéro de la prochaine mission à faire (13 = terminé)
  termine: boolean;
  setParticipantActif: (id: string) => void;
  validerMission: (numero: number, participantIds: string[]) => string[];  // ids ayant terminé la chasse
  ajouterParticipant: (p: Omit<Participant, 'id'>) => void;
  supprimerParticipant: (id: string) => void;
  majCompte: (c: Partial<Compte>) => void;
  reinitialiser: () => void;
};

const CLE_STOCKAGE = 'tdn-etat-v1';

function etatInitial(): Etat {
  const progressions: Record<string, Progression> = {};
  for (const p of COMPTE_DEMO.participants) {
    progressions[p.id] = { participantId: p.id, missionsValidees: PROGRESSION_DEMO[p.id] ?? [] };
  }
  return { compte: COMPTE_DEMO, progressions, participantActifId: 'p1', compteurCle: 83 };
}

function genererCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 4; i++) s += alphabet[Math.floor(Math.random() * alphabet.length)];
  return `NOEL-${s}`;
}

const Contexte = createContext<Ctx | null>(null);

export function TresorsProvider({ children }: { children: React.ReactNode }) {
  const [etat, setEtat] = useState<Etat>(etatInitial);
  const [charge, setCharge] = useState(false);

  useEffect(() => {
    try {
      const brut = localStorage.getItem(CLE_STOCKAGE);
      if (brut) setEtat(JSON.parse(brut));
    } catch { /* ignore */ }
    setCharge(true);
  }, []);

  useEffect(() => {
    if (charge) localStorage.setItem(CLE_STOCKAGE, JSON.stringify(etat));
  }, [etat, charge]);

  const setParticipantActif = useCallback((id: string) => {
    setEtat((e) => ({ ...e, participantActifId: id }));
  }, []);

  const validerMission = useCallback((numero: number, ids: string[]) => {
    const termines: string[] = [];
    setEtat((e) => {
      const progressions = { ...e.progressions };
      let compteur = e.compteurCle;
      for (const id of ids) {
        const p = progressions[id] ?? { participantId: id, missionsValidees: [] };
        if (p.missionsValidees.includes(numero)) continue;
        const missionsValidees = [...p.missionsValidees, numero].sort((a, b) => a - b);
        let cle: Cle | undefined = p.cle;
        if (missionsValidees.length >= EVENEMENT.nbMissions && !cle) {
          compteur += 1;
          cle = { numero: String(compteur).padStart(3, '0'), code: genererCode(), participantId: id, revelee: false };
          termines.push(id);
        }
        progressions[id] = { ...p, missionsValidees, cle };
      }
      return { ...e, progressions, compteurCle: compteur };
    });
    return termines;
  }, []);

  const ajouterParticipant = useCallback((p: Omit<Participant, 'id'>) => {
    setEtat((e) => {
      const id = `p${Date.now()}`;
      return {
        ...e,
        compte: { ...e.compte, participants: [...e.compte.participants, { ...p, id }] },
        progressions: { ...e.progressions, [id]: { participantId: id, missionsValidees: [] } },
      };
    });
  }, []);

  const supprimerParticipant = useCallback((id: string) => {
    setEtat((e) => {
      const participants = e.compte.participants.filter((p) => p.id !== id);
      const progressions = { ...e.progressions };
      delete progressions[id];
      const participantActifId = e.participantActifId === id ? (participants[0]?.id ?? '') : e.participantActifId;
      return { ...e, compte: { ...e.compte, participants }, progressions, participantActifId };
    });
  }, []);

  const majCompte = useCallback((c: Partial<Compte>) => {
    setEtat((e) => ({ ...e, compte: { ...e.compte, ...c } }));
  }, []);

  const reinitialiser = useCallback(() => {
    localStorage.removeItem(CLE_STOCKAGE);
    sessionStorage.removeItem('tdn-intro-vue');
    setEtat(etatInitial());
  }, []);

  const valeur = useMemo<Ctx>(() => {
    const participantActif =
      etat.compte.participants.find((p) => p.id === etat.participantActifId) ?? etat.compte.participants[0];
    const progressionActive =
      etat.progressions[participantActif?.id] ?? { participantId: participantActif?.id, missionsValidees: [] };
    const missionCourante =
      MISSIONS.find((m) => !progressionActive.missionsValidees.includes(m.numero))?.numero ?? EVENEMENT.nbMissions + 1;
    return {
      ...etat,
      participantActif,
      progressionActive,
      missionCourante,
      termine: progressionActive.missionsValidees.length >= EVENEMENT.nbMissions,
      setParticipantActif, validerMission, ajouterParticipant, supprimerParticipant, majCompte, reinitialiser,
    };
  }, [etat, setParticipantActif, validerMission, ajouterParticipant, supprimerParticipant, majCompte, reinitialiser]);

  return <Contexte.Provider value={valeur}>{children}</Contexte.Provider>;
}

export function useTresors() {
  const ctx = useContext(Contexte);
  if (!ctx) throw new Error('useTresors doit être utilisé dans TresorsProvider');
  return ctx;
}
