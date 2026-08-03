import Link from 'next/link'
import { notFound } from 'next/navigation'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty } from '@/lib/ui'
import { VISIBILITY, dayTime, fileSize } from '@/lib/format'
import { FileText, Download } from 'lucide-react'

export const dynamic = 'force-dynamic'

export default async function DocumentPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await db()
  const viewer = (await me())!

  const { data: d } = await supabase
    .from('documents')
    .select('*, folders(name), members(full_name), document_versions(*, members(full_name))')
    .eq('id', id)
    .maybeSingle()
  if (!d) notFound()

  const versions = ((d.document_versions ?? []) as any[]).sort((a, b) => b.version - a.version)
  const latest = versions[0]

  return (
    <article className="mx-auto max-w-4xl">
      <Link href="/documents" className="mb-4 inline-block text-sm text-maroon-700 hover:underline">
        ← Document library
      </Link>

      <Card className="p-6">
        <div className="flex items-start gap-4">
          <FileText size={28} className="mt-1 shrink-0 text-ink-300" />
          <div className="min-w-0 flex-1">
            <h1 className="font-serif text-xl leading-snug text-ink-900">{d.title}</h1>
            <div className="mt-2 flex flex-wrap gap-1.5">
              <Badge tone="navy">{(d.folders as any)?.name ?? 'Uncategorised'}</Badge>
              {d.visibility !== 'all_members' && <Badge tone="amber">{VISIBILITY[d.visibility]}</Badge>}
              {latest && <Badge>Version {latest.version}</Badge>}
            </div>
            {d.description && <p className="mt-3 text-[15px] leading-relaxed text-ink-700">{d.description}</p>}
            {!!(d.tags as string[])?.length && (
              <div className="mt-3 flex flex-wrap gap-1">
                {(d.tags as string[]).map((t) => (
                  <Badge key={t} tone="maroon">{t}</Badge>
                ))}
              </div>
            )}
          </div>
        </div>

        <hr className="my-5 border-sand-200" />

        {/* PRD 3.6 wants in-browser preview, not a forced download. Files are not uploaded
            in this demo, so the viewer is a placeholder rather than a fake PDF. */}
        <div className="flex h-64 flex-col items-center justify-center rounded border border-dashed border-sand-300 bg-sand-50 text-center">
          <FileText size={30} className="text-ink-200" />
          <p className="mt-3 text-sm text-ink-500">{latest?.file_name}</p>
          <p className="mt-1 text-xs text-ink-400">
            In-browser preview appears here once files are uploaded to storage.
          </p>
        </div>

        <div className="mt-4 flex flex-wrap items-center gap-3 text-xs text-ink-400">
          <span>{fileSize(latest?.size_bytes)}</span>
          <span>Uploaded {dayTime(d.created_at)}</span>
          {(d.members as any) && <span>by {(d.members as any).full_name}</span>}
          {viewer.isStaff && (
            <span className="flex items-center gap-1">
              <Download size={11} /> {d.download_count} downloads
            </span>
          )}
        </div>
      </Card>

      <Card className="mt-4 p-5">
        <h2 className="mb-3 text-[15px] text-ink-900">Version history</h2>
        {!versions.length ? (
          <Empty>No versions recorded.</Empty>
        ) : (
          <ul className="divide-y divide-sand-100">
            {versions.map((v) => (
              <li key={v.id} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                <Badge tone={v.version === latest.version ? 'green' : 'neutral'}>v{v.version}</Badge>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm text-ink-700">{v.file_name}</p>
                  <p className="text-xs text-ink-400">
                    {dayTime(v.created_at)}
                    {v.members && ` · ${v.members.full_name}`}
                  </p>
                </div>
                <span className="text-xs text-ink-400">{fileSize(v.size_bytes)}</span>
                {viewer.isStaff && v.version !== latest.version && (
                  <span className="text-xs text-maroon-700">Restore</span>
                )}
              </li>
            ))}
          </ul>
        )}
      </Card>
    </article>
  )
}
