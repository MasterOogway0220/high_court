import Link from 'next/link'
import { db } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading } from '@/lib/ui'
import { day } from '@/lib/format'
import { Avatar } from '../directory/page'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Bar Committee' }

export default async function CommitteePage({
  searchParams,
}: {
  searchParams: Promise<{ term?: string }>
}) {
  const sp = await searchParams
  const supabase = await db()

  const { data: terms } = await supabase.from('committee_terms').select('*').order('start_year', { ascending: false })
  const term = sp.term ? terms?.find((t) => String(t.id) === sp.term) : terms?.find((t) => t.is_current)

  const { data: committees } = await supabase
    .from('committees')
    .select('*, members(id, full_name), committee_members(designation, sort, members(id, full_name, enrolment_no, photo_url, designation))')
    .eq('term_id', term?.id ?? 0)
    .order('sort')

  const byKind = (k: string) => (committees ?? []).filter((c) => c.kind === k)
  const officeBearers = byKind('office_bearers')[0]
  const executive = byKind('executive')[0]
  const standing = [...byKind('standing'), ...byKind('sub')]

  const sorted = (c: any) =>
    ((c?.committee_members ?? []) as any[]).sort((a, b) => a.sort - b.sort)

  return (
    <>
      <Heading sub="Office bearers, the Executive Committee, and the standing and sub-committees of the Association.">
        Bar Committee
      </Heading>

      {/* No term switcher: the page shows the current term. A ?term= link still
          resolves an earlier one, and says so. */}
      {!term?.is_current && (
        <div className="mb-5">
          <Badge tone="warn">Archived term — read only</Badge>
        </div>
      )}

      {!committees?.length ? (
        <Empty>No committees are recorded for this term.</Empty>
      ) : (
        <div className="space-y-8">
          {officeBearers && (
            <section>
              <h2 className="mb-4 text-lg text-ink-900">Office Bearers</h2>
              {(() => {
                const [president, ...others] = sorted(officeBearers)
                return (
                  <>
                    {president && (
                      <Card className="mb-4 flex flex-col gap-5 p-6 sm:flex-row">
                        <Avatar name={president.members.full_name} url={president.members.photo_url} size={20} />
                        <div className="min-w-0 flex-1">
                          <p className="text-[11.5px] font-semibold text-brand-600">
                            {president.designation}
                          </p>
                          <Link
                            href={`/directory/${president.members.id}`}
                            className="mt-1 block font-display text-xl text-ink-900 hover:text-brand-600"
                          >
                            {president.members.full_name}
                          </Link>
                          <p className="mt-0.5 text-sm text-ink-400">{president.members.enrolment_no}</p>
                          <blockquote className="mt-4 border-l-2 border-brand-200 pl-4 text-[15px] leading-relaxed text-ink-600 italic">
                            The Association exists to protect the dignity of the Bar and the interests of every
                            member of it. This dashboard is a step towards making that work visible and accessible
                            to all of you.
                          </blockquote>
                        </div>
                      </Card>
                    )}
                    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                      {others.map((p: any) => (
                        <MemberCard key={p.members.id} p={p} />
                      ))}
                    </div>
                  </>
                )
              })()}
            </section>
          )}

          {executive && (
            <section>
              <h2 className="mb-4 text-lg text-ink-900">Executive Committee</h2>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                {sorted(executive).map((p: any) => (
                  <MemberCard key={p.members.id} p={p} />
                ))}
              </div>
            </section>
          )}

          {!!standing.length && (
            <section>
              <h2 className="mb-4 text-lg text-ink-900">Standing & Sub-Committees</h2>
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {standing.map((c) => (
                  <Link key={c.id} href={`/committee/${c.id}`}>
                    <Card className="h-full p-5 transition-colors hover:border-ink-200">
                      <div className="flex items-start justify-between gap-3">
                        <h3 className="text-[15px] text-ink-900">{c.name}</h3>
                        <Badge>{c.kind === 'sub' ? 'Sub' : 'Standing'}</Badge>
                      </div>
                      {c.mandate && <p className="mt-2 line-clamp-2 text-sm text-ink-500">{c.mandate}</p>}
                      <div className="mt-3 flex items-center gap-2 text-xs text-ink-400">
                        {(c.members as any) && <span>Convenor: {(c.members as any).full_name}</span>}
                        <span>·</span>
                        <span>{(c.committee_members as any[])?.length ?? 0} members</span>
                        {c.formed_on && (
                          <>
                            <span>·</span>
                            <span>Formed {day(c.formed_on)}</span>
                          </>
                        )}
                      </div>
                    </Card>
                  </Link>
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </>
  )
}

function MemberCard({ p }: { p: any }) {
  return (
    <Card className="p-4 text-center">
      <div className="flex justify-center">
        <Avatar name={p.members.full_name} url={p.members.photo_url} size={14} />
      </div>
      <p className="mt-2.5 text-[11.5px] font-semibold text-brand-600">{p.designation}</p>
      <Link href={`/directory/${p.members.id}`} className="mt-1 block text-sm text-ink-900 hover:text-brand-600">
        {p.members.full_name}
      </Link>
      <p className="mt-0.5 text-xs text-ink-400">{p.members.enrolment_no}</p>
    </Card>
  )
}
