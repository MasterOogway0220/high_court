import Link from 'next/link'
import { notFound } from 'next/navigation'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card } from '@/lib/ui'
import { CATEGORY, VISIBILITY, dayTime, fileSize } from '@/lib/format'
import { Paperclip, Pin } from 'lucide-react'

export const dynamic = 'force-dynamic'

export default async function AnnouncementPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await db()
  const viewer = (await me())!

  const { data: a } = await supabase
    .from('announcements')
    .select('*, announcement_attachments(*), members(full_name, enrolment_no)')
    .eq('id', id)
    .maybeSingle()

  if (!a) notFound()

  // read receipt (PRD 3.3) — idempotent, aggregate-only reporting
  await supabase
    .from('announcement_reads')
    .upsert({ announcement_id: a.id, member_id: viewer.id }, { onConflict: 'announcement_id,member_id' })

  const condolence = a.category === 'condolence'
  const files = (a.announcement_attachments ?? []) as {
    id: number; file_name: string; size_bytes: number | null
  }[]

  return (
    <article className="mx-auto max-w-3xl">
      <Link href="/announcements" className="mb-4 inline-block text-sm text-maroon-700 hover:underline">
        ← All announcements
      </Link>

      <Card className={`p-7 sm:p-9 ${condolence ? 'bg-sand-50' : ''}`}>
        <div className="mb-4 flex flex-wrap items-center gap-1.5">
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
        </div>

        <h1
          className={`text-[26px] leading-tight sm:text-3xl ${condolence ? 'font-serif font-normal text-ink-700' : 'text-ink-900'}`}
        >
          {a.title}
        </h1>

        <p className="mt-3 text-sm text-ink-400">
          {dayTime(a.publish_at)}
          {(a.members as { full_name: string } | null) && ` · issued by ${(a.members as any).full_name}`}
        </p>

        <hr className="my-6 border-sand-200" />

        {/* generous measure for reading contexts (PRD 5.3) */}
        <div className="text-[16px] leading-[1.75] whitespace-pre-wrap text-ink-800">{a.body}</div>

        {a.expires_at && (
          <p className="mt-6 text-xs text-ink-400">
            This notice expires on {dayTime(a.expires_at)}.
          </p>
        )}

        {!!files.length && (
          <>
            <hr className="my-6 border-sand-200" />
            <h2 className="mb-3 text-sm font-medium text-ink-700">Attachments</h2>
            <ul className="space-y-2">
              {files.map((f) => (
                <li key={f.id}>
                  <span className="flex items-center gap-2.5 rounded border border-sand-200 px-3 py-2.5 text-sm text-ink-700">
                    <Paperclip size={14} className="text-ink-300" />
                    <span className="min-w-0 flex-1 truncate">{f.file_name}</span>
                    <span className="text-xs text-ink-400">{fileSize(f.size_bytes)}</span>
                  </span>
                </li>
              ))}
            </ul>
          </>
        )}
      </Card>
    </article>
  )
}
