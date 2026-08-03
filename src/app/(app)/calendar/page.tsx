import Link from 'next/link'
import { db, me } from '@/lib/supabase/server'
import { Badge, Button, Card, Empty, Heading } from '@/lib/ui'
import { ENTRY_COLOUR, ENTRY_TYPE, day, time } from '@/lib/format'
import {
  addMonths, endOfMonth, endOfWeek, format, isSameDay, isSameMonth,
  startOfDay, startOfMonth, startOfWeek, eachDayOfInterval,
} from 'date-fns'
import { CalendarDays, Rss } from 'lucide-react'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Calendar' }

export default async function CalendarPage({
  searchParams,
}: {
  searchParams: Promise<{ m?: string; view?: string; type?: string }>
}) {
  const sp = await searchParams
  const supabase = await db()
  const viewer = (await me())!

  const cursor = sp.m ? new Date(`${sp.m}-01T00:00:00`) : new Date()
  const gridStart = startOfWeek(startOfMonth(cursor), { weekStartsOn: 1 })
  const gridEnd = endOfWeek(endOfMonth(cursor), { weekStartsOn: 1 })

  const listMode = sp.view === 'list'
  const from = listMode ? startOfDay(new Date()) : gridStart
  const to = listMode ? addMonths(new Date(), 6) : gridEnd

  let q = supabase
    .from('calendar_entries')
    .select('id, title, entry_type, starts_at, ends_at, all_day, description, event_id')
    .gte('starts_at', from.toISOString())
    .lte('starts_at', to.toISOString())
  if (sp.type) q = q.eq('entry_type', sp.type)

  const { data: entries } = await q.order('starts_at')
  const list = entries ?? []

  const days = eachDayOfInterval({ start: gridStart, end: gridEnd })
  const monthQ = (d: Date) => format(d, 'yyyy-MM')

  // per-member, revocable subscription feed (PRD 3.4)
  const { data: tokenRow } = await supabase.from('ics_tokens').select('token').eq('revoked', false).limit(1).maybeSingle()

  return (
    <>
      <Heading
        eyebrow="Association record"
        sub="Court holidays, meetings, events and elections."
        aside={
          viewer.canPublish ? (
            <Link href="/manage/calendar_entries/new">
              <Button size="sm">New entry</Button>
            </Link>
          ) : null
        }
      >
        Calendar
      </Heading>

      <Card className="mb-4 flex flex-wrap items-center gap-3 p-3">
        <div className="flex items-center gap-1">
          <Link
            href={{ query: { ...sp, m: monthQ(addMonths(cursor, -1)) } }}
            className="rounded border border-paper-edge px-2.5 py-1.5 text-sm text-ink-600 hover:bg-paper-sunk"
            aria-label="Previous month"
          >
            ←
          </Link>
          <Link
            href={{ query: { ...sp, m: monthQ(addMonths(cursor, 1)) } }}
            className="rounded border border-paper-edge px-2.5 py-1.5 text-sm text-ink-600 hover:bg-paper-sunk"
            aria-label="Next month"
          >
            →
          </Link>
        </div>
        <h2 className="text-[15px] text-ink-900">{format(cursor, 'MMMM yyyy')}</h2>

        <form className="ml-auto flex items-center gap-2">
          {sp.view && <input type="hidden" name="view" value={sp.view} />}
          <select
            name="type"
            defaultValue={sp.type ?? ''}
            aria-label="Filter by type"
            className="h-8 rounded border border-paper-edge bg-white px-2 text-sm"
          >
            <option value="">All types</option>
            {Object.entries(ENTRY_TYPE).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </select>
          <button className="h-9 rounded-lg bg-brand-600 px-4 text-[12.5px] font-semibold text-white hover:bg-brand-700">Filter</button>
        </form>

        <div className="flex gap-1 rounded border border-paper-edge p-0.5">
          {[['', 'Month'], ['list', 'List']].map(([v, label]) => (
            <Link
              key={label}
              href={{ query: { ...sp, view: v || undefined } }}
              className={`rounded-lg px-3 py-1 text-[12px] font-semibold ${(sp.view ?? '') === v ? 'bg-brand-600 text-white' : 'text-ink-500 hover:bg-paper-sunk'}`}
            >
              {label}
            </Link>
          ))}
        </div>
      </Card>

      {/* month grid on desktop, list default on mobile (PRD 3.4) */}
      {!listMode && (
        <Card className="hidden overflow-hidden sm:block">
          <div className="grid grid-cols-7 border-b border-paper-edge bg-paper">
            {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => (
              <div key={d} className="px-2 py-2 text-center text-[11px] font-medium tracking-wide text-ink-400 uppercase">
                {d}
              </div>
            ))}
          </div>
          <div className="grid grid-cols-7">
            {days.map((d) => {
              const todays = list.filter((e) => isSameDay(new Date(e.starts_at), d))
              const inMonth = isSameMonth(d, cursor)
              const today = isSameDay(d, new Date())
              return (
                <div
                  key={d.toISOString()}
                  className={`min-h-24 border-r border-b border-paper-sunk p-1.5 ${inMonth ? '' : 'bg-paper/60'}`}
                >
                  <span
                    className={`inline-flex h-5 w-5 items-center justify-center rounded-full text-[11px] ${
                      today ? 'bg-brand-600 font-semibold text-white' : inMonth ? 'text-ink-600' : 'text-ink-200'
                    }`}
                  >
                    {format(d, 'd')}
                  </span>
                  <div className="mt-1 space-y-0.5">
                    {todays.slice(0, 3).map((e) => (
                      <div
                        key={e.id}
                        title={e.title}
                        className={`truncate rounded border px-1 py-0.5 text-[10px] leading-tight ${ENTRY_COLOUR[e.entry_type]}`}
                      >
                        {e.title}
                      </div>
                    ))}
                    {todays.length > 3 && <p className="px-1 text-[10px] text-ink-400">+{todays.length - 3} more</p>}
                  </div>
                </div>
              )
            })}
          </div>
        </Card>
      )}

      <div className={listMode ? '' : 'sm:hidden'}>
        {!list.length ? (
          <Empty>No calendar entries in this period.</Empty>
        ) : (
          <ul className="space-y-2">
            {list.map((e) => (
              <li key={e.id}>
                <Card className="flex gap-4 p-4">
                  <div className="w-12 shrink-0 text-center">
                    <p className="text-[10px] tracking-wide text-ink-400 uppercase">{format(new Date(e.starts_at), 'MMM')}</p>
                    <p className="font-display text-xl text-ink-900">{format(new Date(e.starts_at), 'd')}</p>
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="mb-1 flex flex-wrap items-center gap-1.5">
                      <span className={`rounded border px-1.5 py-0.5 text-[10px] font-medium ${ENTRY_COLOUR[e.entry_type]}`}>
                        {ENTRY_TYPE[e.entry_type]}
                      </span>
                    </div>
                    {e.event_id ? (
                      <Link href={`/events/${e.event_id}`} className="text-sm text-ink-900 hover:text-brand-600">
                        {e.title}
                      </Link>
                    ) : (
                      <p className="text-sm text-ink-900">{e.title}</p>
                    )}
                    <p className="mt-0.5 text-xs text-ink-400">
                      {day(e.starts_at)}
                      {!e.all_day && ` · ${time(e.starts_at)}`}
                    </p>
                    {e.description && <p className="mt-1.5 line-clamp-2 text-sm text-ink-500">{e.description}</p>}
                  </div>
                </Card>
              </li>
            ))}
          </ul>
        )}
      </div>

      <Card className="mt-4 flex flex-wrap items-center gap-3 p-4">
        <Rss size={15} className="text-ink-300" />
        <div className="min-w-0 flex-1">
          <p className="text-sm text-ink-800">Subscribe in Google or Outlook Calendar</p>
          <p className="text-xs text-ink-400">
            {tokenRow
              ? 'Your personal feed link is private and can be revoked at any time from Settings.'
              : 'Generate a personal feed link from Settings.'}
          </p>
        </div>
        {tokenRow && (
          <code className="max-w-full truncate rounded border border-paper-edge bg-paper px-2 py-1 text-[11px] text-ink-500">
            /api/ics/{tokenRow.token}
          </code>
        )}
      </Card>

      <div className="mt-4 flex flex-wrap gap-2">
        {Object.entries(ENTRY_TYPE).map(([v, l]) => (
          <span key={v} className={`rounded border px-2 py-0.5 text-[11px] ${ENTRY_COLOUR[v]}`}>
            {l}
          </span>
        ))}
      </div>
    </>
  )
}
