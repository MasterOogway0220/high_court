import { Suspense } from 'react'
import Link from 'next/link'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading } from '@/lib/ui'
import { CATEGORY, day, ENTRY_COLOUR, ENTRY_TYPE, relativeDay, time } from '@/lib/format'
import { Users, Mail, Landmark, FileText, ArrowRight } from 'lucide-react'

export const dynamic = 'force-dynamic'

/* Each widget is its own async component behind its own Suspense boundary, so a slow or
   failing query degrades to a skeleton instead of taking the page down (PRD 3.1). */

function Panel({ title, href, children }: { title: string; href?: string; children: React.ReactNode }) {
  return (
    <Card className="flex flex-col p-5">
      <div className="mb-3 flex items-baseline justify-between">
        <h2 className="text-[15px] text-ink-900">{title}</h2>
        {href && (
          <Link href={href} className="text-xs text-maroon-700 hover:underline">
            View all
          </Link>
        )}
      </div>
      <div className="flex-1">{children}</div>
    </Card>
  )
}

const Skeleton = () => (
  <Card className="p-5">
    <div className="h-4 w-32 animate-pulse rounded bg-sand-200" />
    <div className="mt-4 space-y-2">
      <div className="h-3 w-full animate-pulse rounded bg-sand-100" />
      <div className="h-3 w-4/5 animate-pulse rounded bg-sand-100" />
    </div>
  </Card>
)

async function Announcements() {
  const supabase = await db()
  const { data } = await supabase
    .from('announcements')
    .select('id, title, category, priority, pinned, publish_at')
    .eq('status', 'published')
    .lte('publish_at', new Date().toISOString())
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
    .order('pinned', { ascending: false })
    .order('publish_at', { ascending: false })
    .limit(3)

  return (
    <Panel title="Latest announcements" href="/announcements">
      {!data?.length ? (
        <Empty>No announcements have been published yet.</Empty>
      ) : (
        <ul className="divide-y divide-sand-100">
          {data.map((a) => (
            <li key={a.id} className="py-2.5 first:pt-0 last:pb-0">
              <Link href={`/announcements/${a.id}`} className="group block">
                <div className="mb-1 flex flex-wrap items-center gap-1.5">
                  {a.pinned && <Badge tone="maroon">Pinned</Badge>}
                  <Badge tone={a.category === 'condolence' ? 'neutral' : 'navy'}>
                    {CATEGORY[a.category] ?? a.category}
                  </Badge>
                  {a.priority === 'urgent' && <Badge tone="maroon">Urgent</Badge>}
                </div>
                <p className="text-sm leading-snug text-ink-800 group-hover:text-maroon-700">{a.title}</p>
                <p className="mt-0.5 text-xs text-ink-400">{day(a.publish_at)}</p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Panel>
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
    <Panel title="Today & this week" href="/calendar">
      {!data?.length ? (
        <Empty>Nothing in the calendar for the next seven days.</Empty>
      ) : (
        <ul className="space-y-2">
          {data.map((e) => (
            <li key={e.id} className="flex items-start gap-3">
              <span
                className={`mt-0.5 shrink-0 rounded border px-1.5 py-0.5 text-[10px] font-medium ${ENTRY_COLOUR[e.entry_type]}`}
              >
                {ENTRY_TYPE[e.entry_type]?.split(' ')[0] ?? 'Other'}
              </span>
              <div className="min-w-0">
                <p className="truncate text-sm text-ink-800">{e.title}</p>
                <p className="text-xs text-ink-400">
                  {relativeDay(e.starts_at)}
                  {!e.all_day && ` · ${time(e.starts_at)}`}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </Panel>
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
    <Panel title="Upcoming events" href="/events">
      {!data?.length ? (
        <Empty>No events are scheduled at present.</Empty>
      ) : (
        <ul className="space-y-3">
          {data.map((e) => {
            const mine = (e.event_rsvps as { status: string; member_id: string }[])?.find(
              (r) => r.member_id === memberId
            )
            return (
              <li key={e.id}>
                <Link href={`/events/${e.id}`} className="group block">
                  <p className="text-sm leading-snug text-ink-800 group-hover:text-maroon-700">{e.title}</p>
                  <p className="mt-0.5 text-xs text-ink-400">
                    {relativeDay(e.starts_at)} · {time(e.starts_at)}
                    {e.venue && ` · ${e.venue}`}
                  </p>
                  <span className="mt-1.5 inline-block">
                    {mine ? (
                      <Badge tone={mine.status === 'attending' ? 'green' : 'neutral'}>
                        {mine.status === 'attending'
                          ? 'Attending'
                          : mine.status === 'maybe'
                            ? 'Maybe'
                            : 'Not attending'}
                      </Badge>
                    ) : (
                      <Badge tone="amber">RSVP pending</Badge>
                    )}
                  </span>
                </Link>
              </li>
            )
          })}
        </ul>
      )}
    </Panel>
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
    <Panel title="Recently added documents" href="/documents">
      {!data?.length ? (
        <Empty>No documents have been uploaded yet.</Empty>
      ) : (
        <ul className="space-y-2.5">
          {data.map((d) => (
            <li key={d.id} className="flex items-start gap-2.5">
              <FileText size={15} className="mt-0.5 shrink-0 text-ink-300" />
              <div className="min-w-0">
                <Link href={`/documents/${d.id}`} className="block truncate text-sm text-ink-800 hover:text-maroon-700">
                  {d.title}
                </Link>
                <p className="text-xs text-ink-400">
                  {(d.folders as any)?.name ?? 'Uncategorised'} · {day(d.created_at)}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </Panel>
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
    <Panel title="Current newsletter" href="/newsletter">
      {!data ? (
        <Empty>No issue has been published yet.</Empty>
      ) : (
        <Link href={`/newsletter/${data.id}`} className="group flex gap-4">
          <div className="flex h-24 w-18 shrink-0 flex-col items-center justify-center rounded-sm bg-ink-900 px-2 text-center">
            <span className="font-serif text-[10px] leading-tight text-white/70">{data.period}</span>
            <span className="mt-1 h-px w-6 bg-maroon-600" />
            <span className="mt-1 font-serif text-[9px] text-white/50">{data.issue_no}</span>
          </div>
          <div className="min-w-0">
            <p className="font-serif text-sm text-ink-900 group-hover:text-maroon-700">{data.title}</p>
            <p className="mt-1 line-clamp-3 text-xs leading-relaxed text-ink-400">{data.editorial}</p>
          </div>
        </Link>
      )}
    </Panel>
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
  const { data: unread } = await supabase.rpc('unread_count')

  const status = member.membership_status as string

  return (
    <>
      <div className="mb-6">
        <p className="text-xs tracking-wider text-ink-400 uppercase">
          {new Date().toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
        </p>
        <Heading>
          {new Date().getHours() < 12
            ? 'Good morning'
            : new Date().getHours() < 17
              ? 'Good afternoon'
              : 'Good evening'}
          , {member.full_name.split(' ')[0]}
        </Heading>
        <div className="-mt-1 flex flex-wrap items-center gap-2">
          <Badge tone="navy">{member.enrolment_no}</Badge>
          <Badge tone={status === 'active' || status === 'life' ? 'green' : 'amber'}>{status}</Badge>
          {!!unread && (
            <Link href="/announcements">
              <Badge tone="maroon">
                {unread} unread {unread === 1 ? 'notice' : 'notices'}
              </Badge>
            </Link>
          )}
        </div>
      </div>

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
          <h2 className="mb-3 text-[15px] text-ink-900">Quick links</h2>
          <ul className="space-y-1">
            {LINKS.map(({ href, label, icon: Icon }) => (
              <li key={href}>
                <Link
                  href={href}
                  className="group flex items-center gap-2.5 rounded px-2 py-2 text-sm text-ink-700 hover:bg-sand-100"
                >
                  <Icon size={15} className="text-ink-400" />
                  {label}
                  <ArrowRight size={13} className="ml-auto text-ink-200 group-hover:text-maroon-700" />
                </Link>
              </li>
            ))}
          </ul>
        </Card>
      </div>
    </>
  )
}
