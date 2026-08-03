import { Suspense } from 'react'
import Link from 'next/link'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, SectionTitle } from '@/lib/ui'
import { CATEGORY, day, ENTRY_COLOUR, ENTRY_TYPE, relativeDay, time } from '@/lib/format'
import { Users, Mail, Landmark, FileText, ArrowRight } from 'lucide-react'

export const dynamic = 'force-dynamic'

/* Each widget is its own async component behind its own Suspense boundary, so a slow or
   failing query degrades to a skeleton instead of taking the page down (PRD 3.1). */

const Skeleton = () => (
  <Card className="p-5">
    <div className="h-3 w-28 animate-pulse rounded-[2px] bg-paper-sunk" />
    <div className="mt-4 space-y-2">
      <div className="h-2.5 w-full animate-pulse rounded-[2px] bg-paper-sunk" />
      <div className="h-2.5 w-4/5 animate-pulse rounded-[2px] bg-paper-sunk" />
    </div>
  </Card>
)

async function Announcements() {
  const supabase = await db()
  const now = new Date().toISOString()
  const { data } = await supabase
    .from('announcements')
    .select('id, title, body, category, priority, pinned, publish_at')
    .eq('status', 'published')
    .lte('publish_at', now)
    .or(`expires_at.is.null,expires_at.gt.${now}`)
    .order('pinned', { ascending: false })
    .order('publish_at', { ascending: false })
    .limit(3)

  return (
    <Card className="p-5">
      <SectionTitle href="/announcements">Latest notices</SectionTitle>
      {!data?.length ? (
        <Empty>No notices have been published yet.</Empty>
      ) : (
        <ul className="divide-y divide-paper-edge">
          {data.map((a) => (
            <li key={a.id} className="py-3 first:pt-0 last:pb-0">
              <Link href={`/announcements/${a.id}`} className="group block">
                <div className="mb-1.5 flex flex-wrap items-center gap-1.5">
                  {a.pinned && <Badge tone="maroon">Pinned</Badge>}
                  <Badge tone={a.category === 'condolence' ? 'neutral' : 'navy'}>
                    {CATEGORY[a.category] ?? a.category}
                  </Badge>
                  {a.priority === 'urgent' && <Badge tone="maroon">Urgent</Badge>}
                  <span className="ml-auto font-mono text-[10.5px] text-ink-300">
                    {day(a.publish_at)}
                  </span>
                </div>
                <p
                  className={`text-[14.5px] leading-snug text-ink-800 group-hover:text-rule ${
                    a.category === 'condolence' ? 'font-display' : ''
                  }`}
                >
                  {a.title}
                </p>
                <p className="mt-1 line-clamp-1 text-[12.5px] text-ink-400">{a.body}</p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}

async function ThisWeek() {
  const supabase = await db()
  const now = new Date()
  const week = new Date(now.getTime() + 7 * 864e5)

  const { data } = await supabase
    .from('calendar_entries')
    .select('id, title, entry_type, starts_at, all_day')
    .gte('starts_at', now.toISOString())
    .lte('starts_at', week.toISOString())
    .order('starts_at')
    .limit(6)

  return (
    <Card className="p-5">
      <SectionTitle href="/calendar">Today &amp; this week</SectionTitle>
      {!data?.length ? (
        <Empty>Nothing listed for the next seven days.</Empty>
      ) : (
        <ul className="space-y-2.5">
          {data.map((e) => (
            <li key={e.id} className="flex items-start gap-2.5">
              <span
                className={`mt-px shrink-0 rounded-[2px] border px-1.5 py-px font-mono text-[9.5px] uppercase ${ENTRY_COLOUR[e.entry_type]}`}
              >
                {ENTRY_TYPE[e.entry_type]?.split(' ')[0] ?? 'Other'}
              </span>
              <div className="min-w-0">
                <p className="truncate text-[13.5px] leading-snug text-ink-800">{e.title}</p>
                <p className="font-mono text-[10.5px] text-ink-400">
                  {relativeDay(e.starts_at)}
                  {!e.all_day && ` · ${time(e.starts_at)}`}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}

async function UpcomingEvents({ memberId }: { memberId: string }) {
  const supabase = await db()
  const { data } = await supabase
    .from('events')
    .select('id, title, starts_at, venue, event_rsvps(status, member_id)')
    .gte('starts_at', new Date().toISOString())
    .order('starts_at')
    .limit(3)

  return (
    <Card className="p-5">
      <SectionTitle href="/events">Upcoming events</SectionTitle>
      {!data?.length ? (
        <Empty>No events are scheduled at present.</Empty>
      ) : (
        <ul className="divide-y divide-paper-edge">
          {data.map((e) => {
            const mine = (e.event_rsvps as { status: string; member_id: string }[])?.find(
              (r) => r.member_id === memberId
            )
            return (
              <li key={e.id} className="py-3 first:pt-0 last:pb-0">
                <Link href={`/events/${e.id}`} className="group block">
                  <p className="text-[13.5px] leading-snug text-ink-800 group-hover:text-rule">
                    {e.title}
                  </p>
                  <p className="mt-1 font-mono text-[10.5px] text-ink-400">
                    {relativeDay(e.starts_at)} · {time(e.starts_at)}
                  </p>
                  <span className="mt-2 inline-block">
                    {mine ? (
                      <Badge tone={mine.status === 'attending' ? 'green' : 'neutral'}>
                        {mine.status === 'attending'
                          ? 'Attending'
                          : mine.status === 'maybe'
                            ? 'Maybe'
                            : 'Not attending'}
                      </Badge>
                    ) : (
                      <Badge tone="amber">RSVP due</Badge>
                    )}
                  </span>
                </Link>
              </li>
            )
          })}
        </ul>
      )}
    </Card>
  )
}

async function RecentDocuments() {
  const supabase = await db()
  const { data } = await supabase
    .from('documents')
    .select('id, title, created_at, folders(name)')
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
    .limit(5)

  return (
    <Card className="p-5">
      <SectionTitle href="/documents">Recently filed</SectionTitle>
      {!data?.length ? (
        <Empty>No documents have been filed yet.</Empty>
      ) : (
        <ul className="space-y-2.5">
          {data.map((d) => (
            <li key={d.id} className="flex items-start gap-2.5">
              <FileText size={14} className="mt-0.5 shrink-0 text-ink-300" />
              <div className="min-w-0">
                <Link
                  href={`/documents/${d.id}`}
                  className="block truncate text-[13.5px] text-ink-800 hover:text-rule"
                >
                  {d.title}
                </Link>
                <p className="font-mono text-[10.5px] text-ink-400">
                  {(d.folders as any)?.name ?? 'Uncategorised'} · {day(d.created_at)}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}

async function CurrentNewsletter() {
  const supabase = await db()
  const { data } = await supabase
    .from('newsletter_issues')
    .select('id, issue_no, title, period, editorial')
    .eq('status', 'published')
    .order('published_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  return (
    <Card className="p-5">
      <SectionTitle href="/newsletter">Current issue</SectionTitle>
      {!data ? (
        <Empty>No issue has been published yet.</Empty>
      ) : (
        <Link href={`/newsletter/${data.id}`} className="group flex gap-4">
          <div className="flex h-26 w-19 shrink-0 flex-col items-center justify-center border border-ink-800 bg-ink-900 px-2 text-center">
            <span className="font-display text-[10px] leading-tight text-white/75">{data.period}</span>
            <span className="my-1.5 h-px w-6 bg-rule" />
            <span className="font-mono text-[8px] text-white/40">{data.issue_no}</span>
          </div>
          <div className="min-w-0">
            <p className="font-display text-[15px] text-ink-900 group-hover:text-rule">{data.title}</p>
            <p className="mt-1.5 line-clamp-3 text-[12.5px] leading-relaxed text-ink-400">
              {data.editorial}
            </p>
          </div>
        </Link>
      )}
    </Card>
  )
}

const LINKS = [
  { href: '/directory', label: 'Member directory', icon: Users },
  { href: '/committee', label: 'Bar Committee', icon: Landmark },
  { href: '/contact', label: 'Contact the office', icon: Mail },
]

export default async function DashboardPage() {
  const member = (await me())!
  const supabase = await db()
  const now = new Date()

  // The day's business, resolved together: this is the page's thesis, so it does not
  // sit behind a Suspense boundary — the masthead must be right when it paints.
  const [{ data: unread }, { count: weekEntries }, { count: openRsvps }] = await Promise.all([
    supabase.rpc('unread_count'),
    supabase
      .from('calendar_entries')
      .select('id', { count: 'exact', head: true })
      .gte('starts_at', now.toISOString())
      .lte('starts_at', new Date(now.getTime() + 7 * 864e5).toISOString()),
    supabase
      .from('events')
      .select('id', { count: 'exact', head: true })
      .gte('starts_at', now.toISOString()),
  ])

  const status = member.membership_status as string
  const greeting = now.getHours() < 12 ? 'Good morning' : now.getHours() < 17 ? 'Good afternoon' : 'Good evening'

  const business = [
    [unread ?? 0, unread === 1 ? 'unread notice' : 'unread notices', '/announcements'],
    [weekEntries ?? 0, 'entries this week', '/calendar'],
    [openRsvps ?? 0, openRsvps === 1 ? 'event open' : 'events open', '/events'],
  ] as const

  return (
    <>
      {/* Masthead — the day, then the day's business. */}
      <header className="ruled mb-7 pb-5">
        <p className="eyebrow">
          {now.toLocaleDateString('en-IN', {
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            year: 'numeric',
          })}
        </p>

        <h1 className="mt-2.5 text-[30px] text-ink-900 sm:text-[36px]">
          {greeting}, {member.full_name.split(' ')[0]}
        </h1>

        <div className="mt-3 flex flex-wrap items-center gap-2">
          <Badge tone="navy">{member.enrolment_no}</Badge>
          <Badge tone={status === 'active' || status === 'life' ? 'green' : 'amber'}>{status}</Badge>
        </div>

        <dl className="mt-6 flex flex-wrap gap-x-10 gap-y-4">
          {business.map(([n, label, href]) => (
            <Link key={label} href={href} className="group">
              <dt className="font-display text-[28px] leading-none text-ink-900 group-hover:text-rule">
                {String(n).padStart(2, '0')}
              </dt>
              <dd className="eyebrow mt-1.5">{label}</dd>
            </Link>
          ))}
        </dl>
      </header>

      <div className="grid gap-4 lg:grid-cols-2 xl:grid-cols-3">
        <div className="lg:col-span-1 xl:col-span-2">
          <Suspense fallback={<Skeleton />}>
            <Announcements />
          </Suspense>
        </div>
        <Suspense fallback={<Skeleton />}>
          <ThisWeek />
        </Suspense>
        <Suspense fallback={<Skeleton />}>
          <UpcomingEvents memberId={member.id} />
        </Suspense>
        <Suspense fallback={<Skeleton />}>
          <RecentDocuments />
        </Suspense>
        <Suspense fallback={<Skeleton />}>
          <CurrentNewsletter />
        </Suspense>

        <Card className="p-5">
          <SectionTitle>Quick links</SectionTitle>
          <ul>
            {LINKS.map(({ href, label, icon: Icon }) => (
              <li key={href}>
                <Link
                  href={href}
                  className="group flex items-center gap-2.5 border-b border-paper-edge py-2.5 text-[13.5px] text-ink-700 last:border-0 hover:text-rule"
                >
                  <Icon size={14} className="text-ink-300" />
                  {label}
                  <ArrowRight size={13} className="ml-auto text-ink-200 group-hover:text-rule" />
                </Link>
              </li>
            ))}
          </ul>
        </Card>
      </div>
    </>
  )
}
