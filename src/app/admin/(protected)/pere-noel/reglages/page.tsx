import { requireAdmin } from '@/lib/supabase/server';
import { lireReglagesPn } from '@/lib/pere-noel/db';
import FormReglagesPn from '@/components/pere-noel/FormReglagesPn';

export default async function AdminReglagesPn() {
  const { isAdmin } = await requireAdmin();
  if (!isAdmin) return null;
  const r = await lireReglagesPn();
  const cles = {
    anthropic: !!process.env.ANTHROPIC_API_KEY,
    elevenlabs: !!process.env.ELEVENLABS_API_KEY,
    heygen: !!process.env.HEYGEN_API_KEY,
    voixEnv: process.env.ELEVENLABS_VOICE_ID ?? '',
  };
  return (
    <>
      <div className="adm-h"><div><h1>Réglages du Père Noël</h1><p>Prix, ouverture, image, voix et consignes du script.</p></div></div>
      <FormReglagesPn r={r} cles={cles} />
    </>
  );
}
