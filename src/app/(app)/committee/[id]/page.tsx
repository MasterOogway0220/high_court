import Link from 'next/link'
import { notFound } from 'next/navigation'
import { db } from '@/lib/supabase/server'
import { Badge, Card, Empty } from '@/lib/ui'
import { day } from '@/lib/format'
import { Avatar } from '../../directory/page'
import { FileText } from 'lucide-react'

export const dynamic = 'force-dynamic'

export default async function CommitteeDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await db()

  const { data: c } = await supabase
    .from('committees')
    .select('*, committee_terms(label, is_current), members(id, full_name), committee_members(designation, sort, members(id, full_name, enrolment_no, photo_url))')
    .eq('id', id)
    .maybeSingle()
  if (!c) notFound()

  const { data: docs } = await supabase
    .from('committee_documents')
    .select('documents(id, title, created_at)')
    .eq('committee_id', c.id)

  const people = ((c.committee_members ?? []) as any[]).sort((a, b) => a.sort - b.sort)

  return (
    <div className="mx-auto max-w-4xl">
      <Link href="/committee" className="mb-4 inline-block text-sm text-brand-600 hover:underline">
        ← Bar Committee
      </Link>

      <Card className="p-6">
        <div className="flex flex-wrap items-center gap-2">
          <Badge tone="info">{(c.committee_terms as any)?.label}</Badge>
          <Badge>{c.kind === 'sub' ? 'Sub-committee' : 'Standing committee'}</Badge>
          {!(c.committee_terms as any)?.is_current && <Badge tone="warn">Archived</Badge>}
        </div>
        <h1 className="mt-3 font-display text-2xl text-ink-900">{c.name}</h1>
        {c.mandate && (
          <>
            <p className="mt-4 mb-1 text-xs tracking-wider text-ink-400 uppercase">Terms of reference</p>
            <p className="text-[15px] leading-relaxed text-ink-700">{c.mandate}</p>
          </>
        )}
        {c.formed_on && <p className="mt-4 text-xs text-ink-400">Constituted on {day(c.formed_on)}.</p>}
      </Card>

      <Card className="mt-4 p-5">
        <h2 className="mb-4 text-[15px] text-ink-900">Members</h2>
        {!people.length ? (
          <Empty>No members recorded.</Empty>
        ) : (
          <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {people.map((p) => (
              <li key={p.members.id}>
                <Link href={`/directory/${p.members.id}`} className="flex items-center gap-3 rounded p-2 hover:bg-paper">
                  <Avatar name={p.members.full_name} url={p.members.photo_url} size={10} />
                  <div className="min-w-0">
                    <p className="truncate text-sm text-ink-900">{p.members.full_name}</p>
                    <p className="text-xs text-brand-600">{p.designation}</p>
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card className="mt-4 p-5">
        <h2 className="mb-3 text-[15px] text-ink-900">Associated documents</h2>
        {!docs?.length ? (
          <Empty>No minutes or reports have been linked to this committee.</Empty>
        ) : (
          <ul className="space-y-2">
            {docs.map((d: any) => (
              <li key={d.documents.id}>
                <Link
                  href={`/documents/${d.documents.id}`}
                  className="flex items-center gap-2.5 rounded border border-paper-edge px-3 py-2.5 text-sm text-ink-700 hover:border-ink-200"
                >
                  <FileText size={14} className="text-ink-300" />
                  <span className="min-w-0 flex-1 truncate">{d.documents.title}</span>
                  <span className="text-xs text-ink-400">{day(d.documents.created_at)}</span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  )
}
