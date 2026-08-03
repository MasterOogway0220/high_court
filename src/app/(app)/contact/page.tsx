import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading } from '@/lib/ui'
import { TICKET_CATEGORY, day } from '@/lib/format'
import { ContactForm } from './form'
import { MapPin, Phone, Mail, Clock } from 'lucide-react'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Contact' }

export default async function ContactPage({
  searchParams,
}: {
  searchParams: Promise<{ category?: string; subject?: string }>
}) {
  const sp = await searchParams
  const member = (await me())!
  const supabase = await db()

  const { data: tickets } = await supabase
    .from('tickets')
    .select('id, ref_no, category, subject, status, created_at')
    .eq('member_id', member.id)
    .order('created_at', { ascending: false })
    .limit(10)

  const { data: bearers } = await supabase
    .from('committee_members')
    .select('designation, sort, members(id, full_name, mobile, email, hide_mobile, hide_email)')
    .eq('committee_id', (
      await supabase
        .from('committees')
        .select('id, committee_terms!inner(is_current)')
        .eq('kind', 'office_bearers')
        .eq('committee_terms.is_current', true)
        .maybeSingle()
    ).data?.id ?? 0)
    .order('sort')

  const tone = (s: string) => (s === 'resolved' ? 'green' : s === 'in_progress' ? 'amber' : 'navy')

  return (
    <>
      <Heading sub="Reach the Association office, or raise an enquiry and track it to resolution.">Contact</Heading>

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="space-y-4 lg:col-span-2">
          <Card className="p-6">
            <h2 className="mb-4 text-[15px] text-ink-900">Raise an enquiry</h2>
            <ContactForm
              enrolmentNo={member.enrolment_no}
              defaultCategory={sp.category}
              defaultSubject={sp.subject}
            />
          </Card>

          <Card className="p-5">
            <h2 className="mb-3 text-[15px] text-ink-900">Your enquiries</h2>
            {!tickets?.length ? (
              <Empty>You have not raised any enquiries yet.</Empty>
            ) : (
              <ul className="divide-y divide-sand-100">
                {tickets.map((t) => (
                  <li key={t.id} className="flex flex-wrap items-center gap-2 py-3 first:pt-0 last:pb-0">
                    <code className="rounded bg-sand-100 px-1.5 py-0.5 text-[11px] text-ink-500">{t.ref_no}</code>
                    <span className="min-w-0 flex-1 truncate text-sm text-ink-800">{t.subject}</span>
                    <Badge>{TICKET_CATEGORY[t.category]}</Badge>
                    <Badge tone={tone(t.status)}>{t.status.replace('_', ' ')}</Badge>
                    <span className="text-xs text-ink-400">{day(t.created_at)}</span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <div className="space-y-4">
          <Card className="p-5">
            <h2 className="mb-3 text-[15px] text-ink-900">Association office</h2>
            <ul className="space-y-3 text-sm text-ink-700">
              <li className="flex gap-2.5">
                <MapPin size={15} className="mt-0.5 shrink-0 text-ink-300" />
                Guwahati High Court Bar Association, Gauhati High Court, Guwahati 781001, Assam
              </li>
              <li className="flex gap-2.5">
                <Phone size={15} className="mt-0.5 shrink-0 text-ink-300" />
                <a href="tel:+913612601234" className="hover:text-maroon-700">+91 361 260 1234</a>
              </li>
              <li className="flex gap-2.5">
                <Mail size={15} className="mt-0.5 shrink-0 text-ink-300" />
                <a href="mailto:office@ghcba.in" className="hover:text-maroon-700">office@ghcba.in</a>
              </li>
              <li className="flex gap-2.5">
                <Clock size={15} className="mt-0.5 shrink-0 text-ink-300" />
                Monday to Friday, 10:30 AM – 4:30 PM
              </li>
            </ul>
            <div className="mt-4 flex h-36 items-center justify-center rounded border border-dashed border-sand-300 bg-sand-50 text-xs text-ink-400">
              Map embed
            </div>
          </Card>

          {!!bearers?.length && (
            <Card className="p-5">
              <h2 className="mb-3 text-[15px] text-ink-900">Office bearers</h2>
              <ul className="space-y-3">
                {bearers.map((b: any) => (
                  <li key={b.members.id}>
                    <p className="text-[11px] font-medium tracking-wide text-maroon-700 uppercase">{b.designation}</p>
                    <p className="text-sm text-ink-800">{b.members.full_name}</p>
                    {!b.members.hide_mobile && (
                      <a href={`tel:${b.members.mobile}`} className="text-xs text-ink-400 hover:text-maroon-700">
                        {b.members.mobile}
                      </a>
                    )}
                  </li>
                ))}
              </ul>
            </Card>
          )}
        </div>
      </div>
    </>
  )
}
