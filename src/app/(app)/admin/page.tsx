import Link from 'next/link'
import { redirect } from 'next/navigation'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading } from '@/lib/ui'
import { TICKET_CATEGORY, dayTime } from '@/lib/format'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Administration' }

export default async function AdminPage() {
  const member = (await me())!
  if (!member.canPublish && !member.isStaff) redirect('/')

  const supabase = await db()

  const [{ data: pending }, { data: tickets }, { data: audit }, { count: members }] = await Promise.all([
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
    supabase.from('audit_log').select('*').order('at', { ascending: false }).limit(15),
    supabase.from('members').select('id', { count: 'exact', head: true }),
  ])

  return (
    <>
      <Heading sub="Moderation queue, open enquiries and the audit trail.">Administration</Heading>

      <div className="mb-4 grid gap-3 sm:grid-cols-3">
        {[
          ['Members', members ?? 0],
          ['Pending profile changes', pending?.length ?? 0],
          ['Open enquiries', tickets?.length ?? 0],
        ].map(([label, n]) => (
          <Card key={label as string} className="p-4">
            <p className="text-xs tracking-wider text-ink-400 uppercase">{label}</p>
            <p className="mt-1 font-serif text-2xl text-ink-900">{n as number}</p>
          </Card>
        ))}
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <h2 className="mb-3 text-[15px] text-ink-900">Profile change requests</h2>
          {!pending?.length ? (
            <Empty>Nothing awaiting approval.</Empty>
          ) : (
            <ul className="divide-y divide-sand-100">
              {pending.map((p: any) => (
                <li key={p.id} className="py-3 first:pt-0 last:pb-0">
                  <p className="text-sm text-ink-900">{p.members?.full_name}</p>
                  <p className="mt-0.5 text-xs text-ink-400">
                    {p.field.replace(/_/g, ' ')}: <span className="line-through">{p.old_value}</span> →{' '}
                    <span className="font-medium text-ink-700">{p.new_value}</span>
                  </p>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="p-5">
          <h2 className="mb-3 text-[15px] text-ink-900">Open enquiries</h2>
          {!tickets?.length ? (
            <Empty>No open enquiries.</Empty>
          ) : (
            <ul className="divide-y divide-sand-100">
              {tickets.map((t: any) => (
                <li key={t.id} className="flex flex-wrap items-center gap-2 py-3 first:pt-0 last:pb-0">
                  <code className="rounded bg-sand-100 px-1.5 py-0.5 text-[11px] text-ink-500">{t.ref_no}</code>
                  <span className="min-w-0 flex-1 truncate text-sm text-ink-800">{t.subject}</span>
                  <Badge tone={t.category === 'grievance' ? 'maroon' : 'neutral'}>
                    {TICKET_CATEGORY[t.category]}
                  </Badge>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card className="p-5 lg:col-span-2">
          <h2 className="mb-1 text-[15px] text-ink-900">Audit trail</h2>
          <p className="mb-3 text-xs text-ink-400">
            Written by a database trigger with no update or delete policy — entries cannot be altered from the
            application.
          </p>
          {!audit?.length ? (
            <Empty>No activity recorded yet.</Empty>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[36rem] text-sm">
                <thead>
                  <tr className="border-b border-sand-200 text-left text-xs tracking-wide text-ink-400 uppercase">
                    <th className="py-2 pr-4 font-medium">When</th>
                    <th className="py-2 pr-4 font-medium">Action</th>
                    <th className="py-2 pr-4 font-medium">Table</th>
                    <th className="py-2 font-medium">Row</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-sand-100">
                  {audit.map((a) => (
                    <tr key={a.id}>
                      <td className="py-2 pr-4 text-xs whitespace-nowrap text-ink-500">{dayTime(a.at)}</td>
                      <td className="py-2 pr-4">
                        <Badge tone={a.action === 'DELETE' ? 'maroon' : a.action === 'INSERT' ? 'green' : 'navy'}>
                          {a.action}
                        </Badge>
                      </td>
                      <td className="py-2 pr-4 text-ink-700">{a.table_name}</td>
                      <td className="py-2 font-mono text-xs text-ink-400">{a.row_id}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>

      <p className="mt-6 text-sm text-ink-400">
        Content creation and approval actions are wired to the database but not yet exposed here —{' '}
        <Link href="/announcements" className="text-maroon-700 hover:underline">
          announcements
        </Link>{' '}
        and documents are seeded for the demo.
      </p>
    </>
  )
}
