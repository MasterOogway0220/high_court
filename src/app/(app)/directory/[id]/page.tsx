import Link from 'next/link'
import { notFound } from 'next/navigation'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading } from '@/lib/ui'
import { DESIGNATION, day } from '@/lib/format'
import { Avatar } from '../page'
import { Mail, Phone, MapPin, EyeOff } from 'lucide-react'

export const dynamic = 'force-dynamic'

export default async function MemberProfile({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await db()
  const viewer = (await me())!

  const { data: m } = await supabase.from('members').select('*').eq('id', id).maybeSingle()
  if (!m) notFound()

  const { data: positions } = await supabase
    .from('committee_members')
    .select('designation, committees(id, name, kind, committee_terms(label, is_current))')
    .eq('member_id', id)

  const { data: pending } = await supabase
    .from('member_profile_changes')
    .select('field, new_value')
    .eq('member_id', id)
    .eq('status', 'pending')

  // PRD 3.2: privacy toggles hide contact details from other members;
  // office bearers always see the full record.
  const full = viewer.canPublish || viewer.id === m.id
  const showMobile = full || !m.hide_mobile
  const showEmail = full || !m.hide_email

  const current = (positions ?? []).filter(
    (p) => (p.committees as any)?.committee_terms?.is_current
  )
  const past = (positions ?? []).filter((p) => !(p.committees as any)?.committee_terms?.is_current)

  return (
    <>
      <Link href="/directory" className="mb-4 inline-block text-sm text-maroon-700 hover:underline">
        ← Back to directory
      </Link>

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="p-6 lg:col-span-2">
          <div className="flex flex-col gap-5 sm:flex-row">
            <Avatar name={m.full_name} url={m.photo_url} size={24} />
            <div className="min-w-0 flex-1">
              <h1 className="font-serif text-2xl text-ink-900">{m.full_name}</h1>
              <p className="mt-1 text-sm text-ink-600">{DESIGNATION[m.designation]}</p>
              <div className="mt-3 flex flex-wrap gap-1.5">
                <Badge tone="navy">{m.enrolment_no}</Badge>
                <Badge tone={['active', 'life'].includes(m.membership_status) ? 'green' : 'amber'}>
                  {m.membership_status}
                </Badge>
                {m.enrolment_date && <Badge>Enrolled {day(m.enrolment_date)}</Badge>}
              </div>

              {!!(m.practice_areas as string[])?.length && (
                <div className="mt-4">
                  <p className="mb-1.5 text-xs tracking-wider text-ink-400 uppercase">Practice areas</p>
                  <div className="flex flex-wrap gap-1.5">
                    {(m.practice_areas as string[]).map((a) => (
                      <Badge key={a} tone="maroon">{a}</Badge>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>

          {m.bio && (
            <>
              <hr className="my-5 border-sand-200" />
              <p className="text-[15px] leading-relaxed text-ink-700">{m.bio}</p>
            </>
          )}

          {!!pending?.length && viewer.id === m.id && (
            <div className="mt-5 rounded border border-amber-200 bg-amber-50 p-3">
              <p className="text-[13px] font-medium text-amber-900">Awaiting approval</p>
              <ul className="mt-1 space-y-0.5 text-xs text-amber-800">
                {pending.map((p, i) => (
                  <li key={i}>
                    {p.field.replace(/_/g, ' ')} → <span className="font-medium">{p.new_value}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Card>

        <div className="space-y-4">
          <Card className="p-5">
            <h2 className="mb-3 text-[15px] text-ink-900">Contact</h2>
            <ul className="space-y-3 text-sm">
              {m.chamber_address && (
                <li className="flex gap-2.5">
                  <MapPin size={15} className="mt-0.5 shrink-0 text-ink-300" />
                  <span className="text-ink-700">{m.chamber_address}</span>
                </li>
              )}
              {m.chamber_phone && (
                <li className="flex gap-2.5">
                  <Phone size={15} className="mt-0.5 shrink-0 text-ink-300" />
                  <span className="text-ink-700">{m.chamber_phone}</span>
                </li>
              )}
              <li className="flex gap-2.5">
                <Phone size={15} className="mt-0.5 shrink-0 text-ink-300" />
                {showMobile ? (
                  <a href={`tel:${m.mobile}`} className="text-ink-700 hover:text-maroon-700">{m.mobile}</a>
                ) : (
                  <span className="flex items-center gap-1.5 text-ink-300">
                    <EyeOff size={13} /> Hidden by member
                  </span>
                )}
              </li>
              <li className="flex gap-2.5">
                <Mail size={15} className="mt-0.5 shrink-0 text-ink-300" />
                {showEmail ? (
                  <a href={`mailto:${m.email}`} className="break-all text-ink-700 hover:text-maroon-700">{m.email}</a>
                ) : (
                  <span className="flex items-center gap-1.5 text-ink-300">
                    <EyeOff size={13} /> Hidden by member
                  </span>
                )}
              </li>
            </ul>
            {viewer.canPublish && (m.hide_mobile || m.hide_email) && (
              <p className="mt-3 border-t border-sand-100 pt-3 text-[11px] text-ink-400">
                Shown in full because you are an office bearer.
              </p>
            )}
          </Card>

          <Card className="p-5">
            <h2 className="mb-3 text-[15px] text-ink-900">Committee positions</h2>
            {!current.length && !past.length ? (
              <Empty>No committee positions on record.</Empty>
            ) : (
              <div className="space-y-4">
                {!!current.length && (
                  <ul className="space-y-2">
                    {current.map((p, i) => {
                      const c = p.committees as any
                      return (
                        <li key={i}>
                          <Link href={`/committee/${c.id}`} className="text-sm text-ink-800 hover:text-maroon-700">
                            {c.name}
                          </Link>
                          <p className="text-xs text-ink-400">
                            {p.designation} · {c.committee_terms.label}
                          </p>
                        </li>
                      )
                    })}
                  </ul>
                )}
                {!!past.length && (
                  <div>
                    <p className="mb-1.5 text-xs tracking-wider text-ink-400 uppercase">Past</p>
                    <ul className="space-y-1.5">
                      {past.map((p, i) => {
                        const c = p.committees as any
                        return (
                          <li key={i} className="text-xs text-ink-400">
                            {c.name} — {p.designation} ({c.committee_terms.label})
                          </li>
                        )
                      })}
                    </ul>
                  </div>
                )}
              </div>
            )}
          </Card>

          {viewer.id === m.id && (
            <Link href="/settings" className="block">
              <Card className="p-4 text-center text-sm text-maroon-700 transition-colors hover:border-maroon-200">
                Edit my profile
              </Card>
            </Link>
          )}
        </div>
      </div>
    </>
  )
}
