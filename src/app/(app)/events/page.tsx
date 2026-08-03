import Link from 'next/link'
import { db } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading } from '@/lib/ui'
import { EVENT_TYPE, day, time } from '@/lib/format'
import { MapPin, Users } from 'lucide-react'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Events' }

export default async function EventsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>
}) {
  const { tab } = await searchParams
  const past = tab === 'archive'
  const supabase = await db()
  const now = new Date().toISOString()

  const { data } = await supabase
    .from('events')
    .select('id, title, description, event_type, starts_at, venue, capacity, banner_url, event_rsvps(status, guests, waitlisted)')
    [past ? 'lt' : 'gte']('starts_at', now)
    .order('starts_at', { ascending: !past })
    .limit(40)

  return (
    <>
      <Heading sub="Seminars, training, meetings and association gatherings.">Events</Heading>

      <div className="mb-4 flex gap-1 border-b border-sand-200">
        {[
          ['', 'Upcoming'],
          ['archive', 'Archive'],
        ].map(([v, label]) => (
          <Link
            key={label}
            href={v ? `/events?tab=${v}` : '/events'}
            className={`-mb-px border-b-2 px-4 py-2 text-sm ${
              (tab ?? '') === v
                ? 'border-maroon-700 font-medium text-ink-900'
                : 'border-transparent text-ink-400 hover:text-ink-700'
            }`}
          >
            {label}
          </Link>
        ))}
      </div>

      {!data?.length ? (
        <Empty>{past ? 'No past events on record.' : 'No events are scheduled at present.'}</Empty>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {data.map((e) => {
            const rsvps = (e.event_rsvps ?? []) as { status: string; guests: number; waitlisted: boolean }[]
            const going = rsvps.filter((r) => r.status === 'attending' && !r.waitlisted)
            const seats = going.reduce((n, r) => n + 1 + r.guests, 0)

            return (
              <Link key={e.id} href={`/events/${e.id}`}>
                <Card className="flex h-full flex-col overflow-hidden transition-colors hover:border-ink-200">
                  <div className="flex h-24 items-end bg-ink-900 p-4">
                    <Badge tone="navy" className="border-white/20 bg-white/10 text-white">
                      {EVENT_TYPE[e.event_type]}
                    </Badge>
                  </div>
                  <div className="flex flex-1 flex-col p-5">
                    <p className="text-xs font-medium tracking-wide text-maroon-700 uppercase">
                      {day(e.starts_at)} · {time(e.starts_at)}
                    </p>
                    <h2 className="mt-1.5 text-[15px] leading-snug text-ink-900">{e.title}</h2>
                    <p className="mt-2 line-clamp-2 flex-1 text-sm text-ink-500">{e.description}</p>

                    <div className="mt-4 space-y-1.5 text-xs text-ink-400">
                      {e.venue && (
                        <p className="flex items-center gap-1.5">
                          <MapPin size={12} /> {e.venue}
                        </p>
                      )}
                      <p className="flex items-center gap-1.5">
                        <Users size={12} />
                        {seats} attending
                        {e.capacity ? ` of ${e.capacity}` : ''}
                      </p>
                    </div>
                  </div>
                </Card>
              </Link>
            )
          })}
        </div>
      )}
    </>
  )
}
