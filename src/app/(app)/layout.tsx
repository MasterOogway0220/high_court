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

  return (
    <div className="flex min-h-dvh flex-col">
      <header className="sticky top-0 z-40 border-b border-ink-800 bg-ink-900">
        <div className="mx-auto flex h-14 max-w-[1400px] items-center gap-3 px-4 sm:px-6">
          <Link href="/" className="flex shrink-0 items-center gap-2.5">
            <span className="flex h-8 w-8 items-center justify-center rounded-full border border-white/25 font-serif text-[13px] text-white">
              GH
            </span>
            <span className="hidden font-serif text-[15px] text-white sm:block">GHCBA</span>
          </Link>

          <div className="mx-auto w-full max-w-md">
            <GlobalSearch />
          </div>

          <Link
            href="/notifications"
            aria-label={`Notifications${unreadNotifs ? `, ${unreadNotifs} unread` : ''}`}
            className="relative rounded p-2 text-white/70 transition-colors hover:bg-white/10 hover:text-white"
          >
            <Bell size={18} />
            {!!unreadNotifs && (
              <span className="absolute top-1 right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-maroon-600 px-1 text-[10px] font-semibold text-white">
                {unreadNotifs > 9 ? '9+' : unreadNotifs}
              </span>
            )}
          </Link>

          <div className="hidden items-center gap-3 border-l border-white/15 pl-3 md:flex">
            <div className="text-right leading-tight">
              <div className="text-[13px] font-medium text-white">{member.full_name}</div>
              <div className="text-[11px] text-white/50">{member.enrolment_no}</div>
            </div>
            <form action={signOut}>
              <button className="rounded px-2 py-1 text-xs text-white/60 transition-colors hover:bg-white/10 hover:text-white">
                Sign out
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="mx-auto flex w-full max-w-[1400px] flex-1 gap-8 px-4 py-6 sm:px-6">
        <Nav canPublish={member.canPublish} isStaff={member.isStaff} />
        <main className="min-w-0 flex-1 pb-16">{children}</main>
      </div>

      <footer className="border-t border-sand-200 bg-sand-100">
        <div className="mx-auto max-w-[1400px] px-4 py-5 text-xs text-ink-400 sm:px-6">
          Guwahati High Court Bar Association · Gauhati High Court, Guwahati 781001
        </div>
      </footer>
    </div>
  )
}
