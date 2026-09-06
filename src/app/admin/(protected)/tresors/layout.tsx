import NavTdnAdmin from '@/components/tresors/NavTdnAdmin';

export default function LayoutTdn({ children }: { children: React.ReactNode }) {
  return (
    <>
      <NavTdnAdmin />
      {children}
    </>
  );
}
