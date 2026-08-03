import Link from 'next/link'
import { db } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading, Input, Select } from '@/lib/ui'
import { CATEGORY, VISIBILITY, ago, day } from '@/lib/format'
import { Pin, Paperclip } from 'lucide-react'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Announcements' }

export default async function AnnouncementsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; category?: string; from?: string; to?: string; archive?: string }>
}) {
  const sp = await searchParams
  const supabase = await db()
  const now = new Date().toISOString()

  let query = supabase
    .from('announcements')
    .select('id, title, body, category, priority, visibility, pinned, publish_at, expires_at, announcement_attachments(id), announcement_reads(member_id)')
    .eq('status', 'published')
    .lte('publish_at', now)

  // PRD 3.3: expired notices leave the feed but stay in the archive.
  if (!sp.archive) query = query.or(`expires_at.is.null,expires_at.gt.${now}`)

  if (sp.q?.trim()) query = query.or(`title.ilike.%${sp.q.trim()}%,body.ilike.%${sp.q.trim()}%`)
  if (sp.category) query = query.eq('category', sp.category)
  if (sp.from) query = query.gte('publish_at', sp.from)
  if (sp.to) query = query.lte('publish_at', `${sp.to}T23:59:59`)

  const { data } = await query
    .order('pinned', { ascending: false })
    .order('publish_at', { ascending: false })
    .limit(60)

  return (
    <>
      <Heading sub="Circulars, court notices and association communications.">Announcements</Heading>

      <Card className="mb-4 p-4">
        <form className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <Input name="q" defaultValue={sp.q} placeholder="Search notices" className="lg:col-span-2" aria-label="Search announcements" />
          <Select name="category" defaultValue={sp.category ?? ''} aria-label="Category">
            <option value="">All categories</option>
            {Object.entries(CATEGORY).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </Select>
          <Input name="from" type="date" defaultValue={sp.from} aria-label="Published from" />
          <Input name="to" type="date" defaultValue={sp.to} aria-label="Published to" />
          <div className="flex items-center gap-3 sm:col-span-2 lg:col-span-5">
            <button className="h-9 rounded bg-ink-900 px-4 text-sm font-medium text-white hover:bg-ink-800">Filter</button>
            <Link href="/announcements" className="text-sm text-ink-500 hover:underline">Clear</Link>
            <label className="ml-auto flex items-center gap-2 text-sm text-ink-600">
              <input type="checkbox" name="archive" value="1" defaultChecked={!!sp.archive} className="accent-maroon-700" />
              Include expired (archive)
            </label>
          </div>
        </form>
      </Card>

      {!data?.length ? (
        <Empty>No announcements match these filters.</Empty>
      ) : (
        <ul className="space-y-3">
          {data.map((a) => {
            const condolence = a.category === 'condolence'
            const expired = a.expires_at && new Date(a.expires_at) < new Date()
            const unread = !(a.announcement_reads as { member_id: string }[])?.length
            const files = (a.announcement_attachments as { id: number }[])?.length ?? 0

            return (
              <li key={a.id}>
                <Link href={`/announcements/${a.id}`}>
                  <Card
                    className={`p-5 transition-colors hover:border-ink-200 ${
                      condolence
                        ? 'border-l-2 border-l-ink-300 bg-sand-50'
                        : a.priority === 'urgent'
                          ? 'border-l-2 border-l-maroon-700'
                          : a.priority === 'important'
                            ? 'border-l-2 border-l-amber-500'
                            : ''
                    }`}
                  >
                    <div className="mb-2 flex flex-wrap items-center gap-1.5">
                      {a.pinned && (
                        <span className="flex items-center gap-1 text-[11px] font-medium text-maroon-700">
                          <Pin size={11} /> Pinned
                        </span>
                      )}
                      <Badge tone={condolence ? 'neutral' : 'navy'}>{CATEGORY[a.category]}</Badge>
                      {a.priority !== 'normal' && !condolence && (
                        <Badge tone={a.priority === 'urgent' ? 'maroon' : 'amber'}>{a.priority}</Badge>
                      )}
                      {a.visibility !== 'all_members' && <Badge tone="amber">{VISIBILITY[a.visibility]}</Badge>}
                      {expired && <Badge>Expired</Badge>}
                      {unread && <span className="ml-auto h-2 w-2 rounded-full bg-maroon-600" aria-label="Unread" />}
                    </div>

                    <h2
                      className={`text-[17px] leading-snug ${condolence ? 'font-serif text-ink-700' : 'text-ink-900'}`}
                    >
                      {a.title}
                    </h2>
                    <p className="mt-1.5 line-clamp-2 text-sm leading-relaxed text-ink-500">{a.body}</p>

                    <div className="mt-3 flex items-center gap-3 text-xs text-ink-400">
                      <span>{day(a.publish_at)}</span>
                      <span>·</span>
                      <span>{ago(a.publish_at)}</span>
                      {files > 0 && (
                        <span className="flex items-center gap-1">
                          <Paperclip size={12} /> {files}
                        </span>
                      )}
                    </div>
                  </Card>
                </Link>
              </li>
            )
          })}
        </ul>
      )}
    </>
  )
}
