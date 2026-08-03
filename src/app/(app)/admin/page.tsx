import Link from 'next/link'
import { redirect } from 'next/navigation'
import { db, me } from '@/lib/supabase/server'
import { Badge, Button, Card, Empty, Heading, SectionTitle } from '@/lib/ui'
import { TICKET_CATEGORY, dayTime, day } from '@/lib/format'
import { reviewProfileChange, setTicketStatus } from '../manage/actions'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Administration' }

const NEW_RECORDS = [
  ['announcements', 'Notice'],
  ['events', 'Event'],
  ['calendar_entries', 'Calendar entry'],
  ['documents', 'Document'],
  ['newsletter_issues', 'Newsletter issue'],
  ['members', 'Member'],
] as const

export default async function AdminPage() {
  const member = (await me())!
  if (!member.canPublish && !member.isStaff) redirect('/')

  const supabase = await db()

  const [{ data: pending }, { data: tickets }, { data: audit }, { count: members }, { data: binned }] =
    await Promise.all([
      supabase
        .from('member_profile_changes')
        .select('*, members(full_name, enrolment_no)')
        .eq('status', 'pending')
        .order('created_at', { ascending: false }),
      supabase
        .from('tickets')
        .select('id, ref_no, subject, category, status, created_at, members(full_name)')
        .neq('status', 'resolved')
        .order('created_at', { ascending: false })
        .limit(10),
      supabase.from('audit_log').select('*').order('at', { ascending: false }).limit(12),
      supabase.from('members').select('id', { count: 'exact', head: true }),
      supabase
        .from('documents')
        .select('id, title, deleted_at')
        .not('deleted_at', 'is', null)
        .order('deleted_at', { ascending: false })
        .limit(5),
    ])

  return (
    <>
      <Heading eyebrow="Office" sub="Create records, clear the moderation queue and read the audit trail.">
        Administration
      </Heading>

      <Card className="mb-4 p-5">
        <SectionTitle>Create a record</SectionTitle>
        <div className="flex flex-wrap gap-2">
          {NEW_RECORDS.map(([table, label]) => (
            <Link key={table} href={`/manage/${table}/new`}>
              <Button variant="outline" size="sm">
                New {label.toLowerCase()}
              </Button>
            </Link>
          ))}
        </div>
      </Card>

      <div className="mb-4 grid gap-3 sm:grid-cols-3">
        {[
          ['Members on the roll', members ?? 0],
          ['Awaiting approval', pending?.length ?? 0],
          ['Open enquiries', tickets?.length ?? 0],
        ].map(([label, n]) => (
          <Card key={label as string} className="p-4">
            <p className="font-display text-[26px] leading-none text-ink-900">
              {String(n).padStart(2, '0')}
            </p>
            <p className="eyebrow mt-2">{label}</p>
          </Card>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <SectionTitle>Profile changes</SectionTitle>
          {!pending?.length ? (
            <Empty>Nothing is awaiting approval.</Empty>
          ) : (
            <ul className="divide-y divide-paper-edge">
              {pending.map((p: any) => (
                <li key={p.id} className="py-3 first:pt-0 last:pb-0">
                  <p className="text-[13.5px] text-ink-900">{p.members?.full_name}</p>
                  <p className="mt-0.5 font-mono text-[11px] text-ink-400">
                    {p.field.replace(/_/g, ' ')}: <span className="line-through">{p.old_value}</span> →{' '}
                    <span className="text-ink-700">{p.new_value}</span>
                  </p>
                  <div className="mt-2 flex gap-2">
                    <form action={reviewProfileChange.bind(null, String(p.id), true)}>
                      <Button size="sm" variant="outline">
                        Approve
                      </Button>
                    </form>
                    <form action={reviewProfileChange.bind(null, String(p.id), false)}>
                      <Button size="sm" variant="ghost">
                        Reject
                      </Button>
                    </form>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="p-5">
          <SectionTitle>Open enquiries</SectionTitle>
          {!tickets?.length ? (
            <Empty>No open enquiries.</Empty>
          ) : (
            <ul className="divide-y divide-paper-edge">
              {tickets.map((t: any) => (
                <li key={t.id} className="py-3 first:pt-0 last:pb-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <code className="rounded-[2px] bg-paper-sunk px-1.5 py-px text-[10.5px] text-ink-500">
                      {t.ref_no}
                    </code>
                    <Badge tone={t.category === 'grievance' ? 'maroon' : 'neutral'}>
                      {TICKET_CATEGORY[t.category]}
                    </Badge>
                    <span className="ml-auto font-mono text-[10.5px] text-ink-300">{day(t.created_at)}</span>
                  </div>
                  <p className="mt-1.5 text-[13.5px] text-ink-800">{t.subject}</p>
                  <div className="mt-2 flex gap-2">
                    {t.status !== 'in_progress' && (
                      <form action={setTicketStatus.bind(null, String(t.id), 'in_progress')}>
                        <Button size="sm" variant="outline">
                          Start
                        </Button>
                      </form>
                    )}
                    <form action={setTicketStatus.bind(null, String(t.id), 'resolved')}>
                      <Button size="sm" variant="outline">
                        Resolve
                      </Button>
                    </form>
                    <Link href={`/manage/tickets/${t.id}`}>
                      <Button size="sm" variant="ghost">
                        Open
                      </Button>
                    </Link>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>

        {!!binned?.length && (
          <Card className="p-5 lg:col-span-2">
            <SectionTitle>Recycle bin</SectionTitle>
            <p className="mb-3 text-[12.5px] text-ink-400">
              Deleted documents remain restorable for thirty days.
            </p>
            <ul className="divide-y divide-paper-edge">
              {binned.map((d) => (
                <li key={d.id} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                  <span className="min-w-0 flex-1 truncate text-[13.5px] text-ink-700">{d.title}</span>
                  <span className="font-mono text-[10.5px] text-ink-300">{day(d.deleted_at!)}</span>
                  <Link href={`/manage/documents/${d.id}`}>
                    <Button size="sm" variant="ghost">
                      Open
                    </Button>
                  </Link>
                </li>
              ))}
            </ul>
          </Card>
        )}

        <Card className="p-5 lg:col-span-2">
          <SectionTitle>Audit trail</SectionTitle>
          <p className="mb-3 text-[12.5px] text-ink-400">
            Written by a database trigger with no update or delete policy. Entries cannot be altered from the
            application.
          </p>
          {!audit?.length ? (
            <Empty>No activity recorded yet.</Empty>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[34rem] text-[13px]">
                <thead>
                  <tr className="border-b border-paper-edge text-left">
                    <th className="eyebrow py-2 pr-4 font-normal">When</th>
                    <th className="eyebrow py-2 pr-4 font-normal">Action</th>
                    <th className="eyebrow py-2 pr-4 font-normal">Table</th>
                    <th className="eyebrow py-2 font-normal">Row</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-paper-edge">
                  {audit.map((a) => (
                    <tr key={a.id}>
                      <td className="py-2 pr-4 font-mono text-[11px] whitespace-nowrap text-ink-500">
                        {dayTime(a.at)}
                      </td>
                      <td className="py-2 pr-4">
                        <Badge tone={a.action === 'DELETE' ? 'maroon' : a.action === 'INSERT' ? 'green' : 'navy'}>
                          {a.action}
                        </Badge>
                      </td>
                      <td className="py-2 pr-4 text-ink-700">{a.table_name}</td>
                      <td className="py-2 font-mono text-[11px] text-ink-400">{a.row_id}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </>
  )
}
