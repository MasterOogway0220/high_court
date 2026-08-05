import Link from 'next/link'
import { redirect } from 'next/navigation'
import { me, db } from '@/lib/supabase/server'
import { Nav } from './nav'
import { GlobalSearch } from './search'
import { Bell, Mail } from 'lucide-react'

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const member = await me()
  if (!member) redirect('/login')

  const supabase = await db()
  const [{ count: unreadNotifs }, { data: unreadNotices }] = await Promise.all([
    supabase.from('notifications').select('id', { count: 'exact', head: true }).is('read_at', null),
    supabase.rpc('unread_count'),
  ])

  const demo = !!process.env.DEMO_AUTO_LOGIN
  const initials = member.full_name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w: string) => w[0])
    .join('')

  return (
    <div className="flex min-h-dvh w-full bg-paper-raised">
      <Nav
        canPublish={member.canPublish || demo}
        isStaff={member.isStaff || demo}
        unread={unreadNotices ?? 0}
        demo={demo}
      />

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="glass backdrop-blur-xl backdrop-saturate-150 sticky top-0 z-30 flex h-19 items-center gap-3 px-4 sm:px-6">
          <Link href="/" className="flex shrink-0 items-center gap-2.5 lg:hidden">
            <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-solid text-[13px] font-extrabold text-on-solid">
              GH
            </span>
          </Link>

          <div className="min-w-0 flex-1 sm:max-w-md">
            <GlobalSearch />
          </div>

          <div className="ml-auto flex items-center gap-2.5">
            <Link
              href="/contact"
              aria-label="Contact the office"
              className="pressable hidden h-10 w-10 items-center justify-center rounded-full bg-paper-sunk text-ink-500 hover:text-ink-900 sm:flex"
            >
              <Mail size={17} />
            </Link>

            <Link
              href="/notifications"
              aria-label={`Notifications${unreadNotifs ? `, ${unreadNotifs} unread` : ''}`}
              className="pressable relative flex h-10 w-10 items-center justify-center rounded-full bg-paper-sunk text-ink-500 hover:text-ink-900"
            >
              <Bell size={17} />
              {!!unreadNotifs && (
                <span className="absolute -top-0.5 -right-0.5 flex h-4.5 min-w-4.5 items-center justify-center rounded-full bg-brand-400 px-1 text-[9.5px] font-bold text-ink-900 tabular-nums">
                  {unreadNotifs > 9 ? '9+' : unreadNotifs}
                </span>
              )}
            </Link>

            <Link
              href="/settings"
              className="pressable flex items-center gap-2.5 rounded-full pl-1 hover:opacity-80"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-400 text-[12.5px] font-bold text-on-accent uppercase">
                {initials}
              </span>
              <span className="hidden leading-tight md:block">
                <span className="block text-[13px] font-semibold text-ink-900">
                  {member.full_name}
                </span>
                <span className="block text-[11.5px] text-ink-400">
                  {member.email ?? member.enrolment_no}
                </span>
              </span>
            </Link>
          </div>
        </header>

        {/* The canvas: cards sit on this, never directly on the shell. Content
            scrolls under the toolbar, so there is no divider to collide with. */}
        <main className="enter min-w-0 flex-1 bg-paper px-4 pt-6 pb-24 sm:px-6 lg:pb-10">
          {children}
        </main>
      </div>
    </div>
  )
}
