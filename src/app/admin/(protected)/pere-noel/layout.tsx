import NavPnAdmin from '@/components/pere-noel/NavPnAdmin';

export default function LayoutPn({ children }: { children: React.ReactNode }) {
  return (
    <>
      <NavPnAdmin />
      {children}
    </>
  );
}
