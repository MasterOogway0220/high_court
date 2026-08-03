import { createClient } from '@supabase/supabase-js'

// Tokenised, revocable, per-member calendar feed (PRD 3.4). Calendar apps cannot carry a
// session cookie, so the token in the URL is the credential — which is why it is revocable
// from Settings. Uses the service key because there is no signed-in user on this request.

export const dynamic = 'force-dynamic'

const admin = () =>
  createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false },
  })

const stamp = (d: string, allDay: boolean) =>
  allDay
    ? new Date(d).toISOString().slice(0, 10).replace(/-/g, '')
    : new Date(d).toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z'

const escape = (s: string) => s.replace(/([,;\\])/g, '\\$1').replace(/\n/g, '\\n')

export async function GET(_req: Request, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params
  const supabase = admin()

  const { data: row } = await supabase
    .from('ics_tokens')
    .select('member_id')
    .eq('token', token)
    .eq('revoked', false)
    .maybeSingle()

  if (!row) return new Response('Feed not found or revoked.', { status: 404 })

  const { data: entries } = await supabase
    .from('calendar_entries')
    .select('id, title, description, starts_at, ends_at, all_day, entry_type')
    .gte('starts_at', new Date(Date.now() - 180 * 864e5).toISOString())
    .order('starts_at')

  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//GHCBA//Member Dashboard//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:GHCBA Calendar',
    'X-WR-TIMEZONE:Asia/Kolkata',
  ]

  for (const e of entries ?? []) {
    const end = e.ends_at ?? e.starts_at
    lines.push(
      'BEGIN:VEVENT',
      `UID:ghcba-${e.id}@ghcba.in`,
      `DTSTAMP:${stamp(new Date().toISOString(), false)}`,
      e.all_day ? `DTSTART;VALUE=DATE:${stamp(e.starts_at, true)}` : `DTSTART:${stamp(e.starts_at, false)}`,
      e.all_day ? `DTEND;VALUE=DATE:${stamp(end, true)}` : `DTEND:${stamp(end, false)}`,
      `SUMMARY:${escape(e.title)}`,
      `CATEGORIES:${escape(e.entry_type)}`,
      ...(e.description ? [`DESCRIPTION:${escape(e.description)}`] : []),
      'END:VEVENT'
    )
  }

  lines.push('END:VCALENDAR')

  return new Response(lines.join('\r\n'), {
    headers: {
      'Content-Type': 'text/calendar; charset=utf-8',
      'Content-Disposition': 'inline; filename="ghcba.ics"',
      'Cache-Control': 'no-store',
    },
  })
}
