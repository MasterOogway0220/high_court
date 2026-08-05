import Link from 'next/link'
import { notFound } from 'next/navigation'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading } from '@/lib/ui'
import { EVENT_TYPE, day, dayTime, time } from '@/lib/format'
import { Rsvp } from './rsvp'
import { Avatar } from '../../directory/page'
import { CalendarDays, MapPin, User, Users } from 'lucide-react'

export const dynamic = 'force-dynamic'

export default async function EventPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await db()
  const viewer = (await me())!

  const { data: e } = await supabase
    .from('events')
    .select('*, members(id, full_name)')
    .eq('id', id)
    .maybeSingle()
  if (!e) notFound()

  // RLS decides what comes back here: own row always, everyone's only if the
  // organiser opened the list or the viewer is an office bearer (PRD 3.5).
  const { data: rsvps } = await supabase
    .from('event_rsvps')
    .select('member_id, status, guests, waitlisted, members(id, full_name, enrolment_no, photo_url)')
    .eq('event_id', e.id)

  const list = (rsvps ?? []) as any[]
  const mine = list.find((r) => r.member_id === viewer.id)
  const going = list.filter((r) => r.status === 'attending' && !r.waitlisted)
  const waiting = list.filter((r) => r.waitlisted)
  const seats = going.reduce((n, r) => n + 1 + r.guests, 0)

  const past = new Date(e.starts_at) < new Date()
  const closed = past || (!!e.rsvp_deadline && new Date(e.rsvp_deadline) < new Date())
  const canSeeList = e.show_attendees || e.organiser_id === viewer.id || viewer.canPublish

  return (
    <>
      <Link href="/events" className="mb-4 inline-block text-sm text-brand-600 hover:underline">
        ← All events
      </Link>

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="space-y-4 lg:col-span-2">
          <Card className="overflow-hidden">
            <div className="board flex h-32 items-end p-5">
              <Badge tone="info" className="bg-white/15 text-white">
                {EVENT_TYPE[e.event_type]}
              </Badge>
            </div>
            <div className="p-6">
              <h1 className="font-display text-2xl leading-tight text-ink-900">{e.title}</h1>
              <div className="mt-4 grid gap-2.5 text-sm text-ink-600 sm:grid-cols-2">
                <p className="flex items-center gap-2">
                  <CalendarDays size={15} className="text-ink-300" />
                  {day(e.starts_at)} · {time(e.starts_at)}
                  {e.ends_at && `–${time(e.ends_at)}`}
                </p>
                {e.venue && (
                  <p className="flex items-center gap-2">
                    <MapPin size={15} className="text-ink-300" /> {e.venue}
                  </p>
                )}
                {(e.members as any) && (
                  <p className="flex items-center gap-2">
                    <User size={15} className="text-ink-300" /> Organised by {(e.members as any).full_name}
                  </p>
                )}
                <p className="flex items-center gap-2">
                  <Users size={15} className="text-ink-300" />
                  {seats} attending{e.capacity ? ` of ${e.capacity}` : ''}
                </p>
              </div>

              <hr className="my-5 border-paper-edge" />
              <p className="text-[15px] leading-relaxed whitespace-pre-wrap text-ink-800">{e.description}</p>

              {e.outcome_note && (
                <div className="mt-6 rounded border border-paper-edge bg-paper p-4">
                  <p className="mb-1 text-xs tracking-wider text-ink-400 uppercase">Outcome</p>
                  <p className="text-sm leading-relaxed text-ink-700">{e.outcome_note}</p>
                </div>
              )}
            </div>
          </Card>

          {canSeeList && (
            <Card className="p-5">
              <h2 className="mb-3 text-[15px] text-ink-900">
                Attendees <span className="text-sm font-normal text-ink-400">({going.length})</span>
              </h2>
              {!going.length ? (
                <Empty>No one has confirmed yet.</Empty>
              ) : (
                <ul className="grid gap-2 sm:grid-cols-2">
                  {going.map((r) => (
                    <li key={r.member_id} className="flex items-center gap-2.5">
                      <Avatar name={r.members.full_name} url={r.members.photo_url} size={8} />
                      <Link href={`/directory/${r.member_id}`} className="truncate text-sm text-ink-700 hover:text-brand-600">
                        {r.members.full_name}
                        {r.guests > 0 && <span className="text-ink-400"> +{r.guests}</span>}
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
              {!!waiting.length && (
                <p className="mt-4 border-t border-paper-sunk pt-3 text-xs text-ink-400">
                  {waiting.length} on the waitlist.
                </p>
              )}
            </Card>
          )}
        </div>

        <div className="space-y-4">
          <Card className="p-5">
            <h2 className="mb-3 text-[15px] text-ink-900">Your RSVP</h2>
            <Rsvp
              eventId={e.id}
              initial={mine?.status ?? null}
              initialGuests={mine?.guests ?? 0}
              waitlisted={mine?.waitlisted ?? false}
              allowGuests={e.allow_guests}
              closed={closed}
            />
            {e.rsvp_deadline && !closed && (
              <p className="mt-3 text-xs text-ink-400">You may change this until {dayTime(e.rsvp_deadline)}.</p>
            )}
          </Card>

          {e.capacity && (
            <Card className="p-5">
              <p className="mb-2 text-xs tracking-wider text-ink-400 uppercase">Capacity</p>
              <div className="h-2 overflow-hidden rounded-full bg-paper-edge">
                <div
                  className="h-full rounded-full bg-solid transition-[width]"
                  style={{ width: `${Math.min(100, (seats / e.capacity) * 100)}%` }}
                />
              </div>
              <p className="mt-2 text-sm text-ink-600">
                {seats} of {e.capacity} places taken
                {waiting.length > 0 && ` · ${waiting.length} waiting`}
              </p>
            </Card>
          )}
        </div>
      </div>
    </>
  )
}
