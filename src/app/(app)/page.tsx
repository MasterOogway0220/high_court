import { Suspense } from 'react'
import Link from 'next/link'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, SectionTitle, cn } from '@/lib/ui'
import { CATEGORY, day, ENTRY_COLOUR, ENTRY_TYPE, relativeDay, time } from '@/lib/format'
import {
  Users,
  FileText,
  ArrowUpRight,
  Megaphone,
  CalendarDays,
  CalendarCheck,
} from 'lucide-react'

export const dynamic = 'force-dynamic'

/* Each widget is its own async component behind its own Suspense boundary, so a slow or
   failing query degrades to a skeleton instead of taking the page down (PRD 3.1). */

const Skeleton = () => (
  <Card className="p-5">
    <div className="h-3.5 w-28 animate-pulse rounded-full bg-paper-sunk" />
    <div className="mt-5 space-y-2.5">
      <div className="hatch h-3 w-full rounded-full" />
      <div className="hatch h-3 w-4/5 rounded-full" />
      <div className="hatch h-3 w-2/3 rounded-full" />
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
                  {a.pinned && <Badge tone="alert">Pinned</Badge>}
                  <Badge tone={a.category === 'condolence' ? 'neutral' : 'info'}>
                    {CATEGORY[a.category] ?? a.category}
                  </Badge>
                  {a.priority === 'urgent' && <Badge tone="alert">Urgent</Badge>}
                  <span className="ml-auto font-mono text-[10.5px] text-ink-300">
                    {day(a.publish_at)}
                  </span>
                </div>
                <p
                  className={`text-[14.5px] leading-snug text-ink-800 group-hover:text-brand-600 ${
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
                className={`mt-px shrink-0 rounded-md border px-1.5 py-0.5 text-[9.5px] font-semibold ${ENTRY_COLOUR[e.entry_type]}`}
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
                  <p className="text-[13.5px] leading-snug text-ink-800 group-hover:text-brand-600">
                    {e.title}
                  </p>
                  <p className="mt-1 font-mono text-[10.5px] text-ink-400">
                    {relativeDay(e.starts_at)} · {time(e.starts_at)}
                  </p>
                  <span className="mt-2 inline-block">
                    {mine ? (
                      <Badge tone={mine.status === 'attending' ? 'success' : 'neutral'}>
                        {mine.status === 'attending'
                          ? 'Attending'
                          : mine.status === 'maybe'
                            ? 'Maybe'
                            : 'Not attending'}
                      </Badge>
                    ) : (
                      <Badge tone="warn">RSVP due</Badge>
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
                  className="block truncate text-[13.5px] text-ink-800 hover:text-brand-600"
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
          <div className="board flex h-26 w-19 shrink-0 flex-col items-center justify-center rounded-xl px-2 text-center">
            <span className="text-[10px] leading-tight font-semibold text-white/80">{data.period}</span>
            <span className="my-1.5 h-px w-6 bg-brand-400" />
            <span className="text-[8px] text-white/45">{data.issue_no}</span>
          </div>
          <div className="min-w-0">
            <p className="text-[14px] font-semibold text-ink-900 group-hover:text-brand-600">{data.title}</p>
            <p className="mt-1.5 line-clamp-3 text-[12.5px] leading-relaxed text-ink-400">
              {data.editorial}
            </p>
          </div>
        </Link>
      )}
    </Card>
  )
}

/** A figure from the day's business. The first one is filled, as the reference does,
    so the row has a head rather than four equal voices. */
function Stat({
  label,
  value,
  note,
  href,
  icon: Icon,
  filled,
}: {
  label: string
  value: number
  note: string
  href: string
  icon: typeof Users
  filled?: boolean
}) {
  return (
    <Link
      href={href}
      className={cn(
        'group flex flex-col justify-between rounded-card p-5 transition-colors',
        filled
          ? 'bg-brand-400 text-ink-900 hover:bg-brand-500'
          : 'border border-paper-edge bg-paper-raised hover:border-brand-400'
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <span className={cn('text-[13px] font-semibold', filled ? 'text-ink-900' : 'text-ink-800')}>
          {label}
        </span>
        <span
          className={cn(
            'flex h-7 w-7 shrink-0 items-center justify-center rounded-full border transition-colors',
            filled
              ? 'border-ink-900/25 text-ink-900 group-hover:bg-ink-900/10'
              : 'border-paper-edge text-ink-500 group-hover:border-brand-400 group-hover:text-ink-900'
          )}
        >
          <ArrowUpRight size={14} />
        </span>
      </div>

      <p
        className={cn(
          'mt-6 text-[34px] leading-none font-bold tracking-tight tabular-nums',
          filled ? 'text-ink-900' : 'text-ink-900'
        )}
      >
        {value}
      </p>

      <div className="mt-4 flex items-center gap-1.5">
        <span
          className={cn(
            'flex h-4.5 w-4.5 items-center justify-center rounded',
            filled ? 'bg-ink-900/12 text-ink-900' : 'bg-brand-100 text-ink-900'
          )}
        >
          <Icon size={11} />
        </span>
        <span className={cn('text-[11px]', filled ? 'text-ink-700' : 'text-ink-400')}>{note}</span>
      </div>
    </Link>
  )
}

export default async function DashboardPage() {
  const member = (await me())!
  const supabase = await db()
  const now = new Date()

  // The day's business, resolved together: this is the page's thesis, so it does not
  // sit behind a Suspense boundary — the header must be right when it paints.
  const [{ data: unread }, { count: weekEntries }, { count: openRsvps }, { count: onRoll }] =
    await Promise.all([
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
      supabase
        .from('members')
        .select('id', { count: 'exact', head: true })
        .in('membership_status', ['active', 'life']),
    ])

  const status = member.membership_status as string
  const greeting = now.getHours() < 12 ? 'Good morning' : now.getHours() < 17 ? 'Good afternoon' : 'Good evening'

  return (
    <>
      <header className="mb-5 flex flex-wrap items-end justify-between gap-4">
        <div className="min-w-0">
          <h1 className="text-[26px] text-ink-900 sm:text-[30px]">
            {greeting}, {member.full_name.split(' ')[0]}
          </h1>
          <p className="mt-1.5 text-[13px] text-ink-400">
            {now.toLocaleDateString('en-IN', {
              weekday: 'long',
              day: 'numeric',
              month: 'long',
              year: 'numeric',
            })}{' '}
            · here is what the Association has on today.
          </p>
        </div>

        <div className="flex shrink-0 items-center gap-2">
          <Badge tone="neutral">{member.enrolment_no}</Badge>
          <Badge tone={status === 'active' || status === 'life' ? 'success' : 'warn'}>{status}</Badge>
        </div>
      </header>

      <div className="mb-4 grid gap-3.5 sm:grid-cols-2 xl:grid-cols-4">
        <Stat
          filled
          label="Unread notices"
          value={unread ?? 0}
          note="Not yet opened"
          href="/announcements"
          icon={Megaphone}
        />
        <Stat
          label="This week"
          value={weekEntries ?? 0}
          note="Next seven days"
          href="/calendar"
          icon={CalendarDays}
        />
        <Stat
          label="Open events"
          value={openRsvps ?? 0}
          note="Accepting RSVPs"
          href="/events"
          icon={CalendarCheck}
        />
        <Stat
          label="Members on roll"
          value={onRoll ?? 0}
          note="Active and life members"
          href="/directory"
          icon={Users}
        />
      </div>

      <div className="grid gap-3.5 lg:grid-cols-2 xl:grid-cols-3">
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
      </div>
    </>
  )
}
