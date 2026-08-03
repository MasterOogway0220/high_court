import Link from 'next/link'
import { redirect } from 'next/navigation'
import { me, db } from '@/lib/supabase/server'
import { signOut } from '../(auth)/login/actions'
import { Nav } from './nav'
import { GlobalSearch } from './search'
import { Bell } from 'lucide-react'

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const member = await me()
  if (!member) redirect('/login')

  const supabase = await db()
  const { count: unreadNotifs } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .is('read_at', null)

  const demo = !!process.env.DEMO_AUTO_LOGIN

  return (
    <div className="flex min-h-dvh flex-col">
      {/* The file cover: dark board, the association's name set as a title page. */}
      <header className="sticky top-0 z-40 border-b border-rule/60 bg-ink-900">
        <div className="mx-auto flex h-15 max-w-[1440px] items-center gap-4 px-4 sm:px-6">
          <Link href="/" className="flex shrink-0 items-center gap-3">
            <span className="flex h-9 w-9 items-center justify-center rounded-[2px] border border-white/25 font-display text-[13px] text-white">
              GH
            </span>
            <span className="hidden leading-none sm:block">
              <span className="block font-display text-[15px] tracking-tight text-white">
                Guwahati High Court
              </span>
              <span className="mt-1 block font-mono text-[9.5px] tracking-[0.18em] text-white/45 uppercase">
                Bar Association
              </span>
            </span>
          </Link>

          <div className="mx-auto w-full max-w-lg">
            <GlobalSearch />
          </div>

          <Link
            href="/notifications"
            aria-label={`Notifications${unreadNotifs ? `, ${unreadNotifs} unread` : ''}`}
            className="relative rounded-[3px] p-2 text-white/60 transition-colors hover:bg-white/10 hover:text-white"
          >
            <Bell size={17} />
            {!!unreadNotifs && (
              <span className="absolute top-1 right-1 flex h-4 min-w-4 items-center justify-center rounded-[2px] bg-rule px-1 font-mono text-[9px] font-medium text-white">
                {unreadNotifs > 9 ? '9+' : unreadNotifs}
              </span>
            )}
          </Link>

          <div className="hidden items-center gap-3 border-l border-white/15 pl-4 md:flex">
            <div className="text-right leading-tight">
              <div className="text-[13px] font-medium text-white">{member.full_name}</div>
              <div className="font-mono text-[10.5px] text-white/45">{member.enrolment_no}</div>
            </div>
            {!demo && (
              <form action={signOut}>
                <button className="rounded-[3px] px-2 py-1 font-mono text-[10.5px] tracking-wide text-white/50 uppercase transition-colors hover:bg-white/10 hover:text-white">
                  Sign out
                </button>
              </form>
            )}
          </div>
        </div>
      </header>

      <div className="mx-auto flex w-full max-w-[1440px] flex-1 gap-7 px-4 py-7 sm:px-6">
        <Nav canPublish={member.canPublish || demo} isStaff={member.isStaff || demo} />
        {/* The signature: filed pleading paper, ruled down the left margin. */}
        <main className="margin-rule enter min-w-0 flex-1 pb-24 lg:pb-10">{children}</main>
      </div>

      <footer className="border-t border-paper-edge bg-paper-sunk">
        <div className="mx-auto flex max-w-[1440px] flex-wrap items-center justify-between gap-2 px-4 py-5 sm:px-6">
          <p className="font-display text-[12.5px] text-ink-600">
            Guwahati High Court Bar Association
          </p>
          <p className="font-mono text-[10.5px] tracking-wide text-ink-400 uppercase">
            Gauhati High Court · Guwahati 781001 · Assam
          </p>
        </div>
      </footer>
    </div>
  )
}
