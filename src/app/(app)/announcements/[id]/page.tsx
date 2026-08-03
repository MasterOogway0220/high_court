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
      <div className="mb-5 flex items-center justify-between gap-3">
        <Link href="/announcements" className="font-mono text-[11px] text-brand-600 hover:underline">
          ← Announcements
        </Link>
        {viewer.canPublish && (
          <Link
            href={`/manage/announcements/${a.id}`}
            className="font-mono text-[11px] text-ink-500 hover:text-brand-600 hover:underline"
          >
            Edit notice
          </Link>
        )}
      </div>

      <Card className={`p-7 sm:p-9 ${condolence ? 'bg-paper' : ''}`}>
        <div className="mb-4 flex flex-wrap items-center gap-1.5">
          {a.pinned && (
            <span className="flex items-center gap-1 text-[11px] font-medium text-brand-600">
              <Pin size={11} /> Pinned
            </span>
          )}
          <Badge tone={condolence ? 'neutral' : 'info'}>{CATEGORY[a.category]}</Badge>
          {a.priority !== 'normal' && !condolence && (
            <Badge tone={a.priority === 'urgent' ? 'alert' : 'warn'}>{a.priority}</Badge>
          )}
          {a.visibility !== 'all_members' && <Badge tone="warn">{VISIBILITY[a.visibility]}</Badge>}
        </div>

        <h1
          className={`text-[26px] leading-tight sm:text-3xl ${condolence ? 'font-display font-normal text-ink-700' : 'text-ink-900'}`}
        >
          {a.title}
        </h1>

        <p className="mt-3 text-sm text-ink-400">
          {dayTime(a.publish_at)}
          {(a.members as { full_name: string } | null) && ` · issued by ${(a.members as any).full_name}`}
        </p>

        <hr className="my-6 border-paper-edge" />

        {/* generous measure for reading contexts (PRD 5.3) */}
        <div className="text-[16px] leading-[1.75] whitespace-pre-wrap text-ink-800">{a.body}</div>

        {a.expires_at && (
          <p className="mt-6 text-xs text-ink-400">
            This notice expires on {dayTime(a.expires_at)}.
          </p>
        )}

        {!!files.length && (
          <>
            <hr className="my-6 border-paper-edge" />
            <h2 className="mb-3 text-sm font-medium text-ink-700">Attachments</h2>
            <ul className="space-y-2">
              {files.map((f) => (
                <li key={f.id}>
                  <span className="flex items-center gap-2.5 rounded border border-paper-edge px-3 py-2.5 text-sm text-ink-700">
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
