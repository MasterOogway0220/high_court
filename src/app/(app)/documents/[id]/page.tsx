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

  // The bucket is private, so the file is reached through a short-lived signed URL.
  // Storage RLS re-checks visibility, so a link cannot outlive the permission.
  const { data: signed } = latest?.file_path
    ? await supabase.storage.from('documents').createSignedUrl(latest.file_path, 300)
    : { data: null }

  return (
    <article className="mx-auto max-w-4xl">
      <Link href="/documents" className="mb-4 inline-block text-sm text-brand-600 hover:underline">
        ← Document library
      </Link>

      <Card className="p-6">
        <div className="flex items-start gap-4">
          <FileText size={28} className="mt-1 shrink-0 text-ink-300" />
          <div className="min-w-0 flex-1">
            <h1 className="font-display text-xl leading-snug text-ink-900">{d.title}</h1>
            <div className="mt-2 flex flex-wrap gap-1.5">
              <Badge tone="info">{(d.folders as any)?.name ?? 'Uncategorised'}</Badge>
              {d.visibility !== 'all_members' && <Badge tone="warn">{VISIBILITY[d.visibility]}</Badge>}
              {latest && <Badge>Version {latest.version}</Badge>}
            </div>
            {d.description && <p className="mt-3 text-[15px] leading-relaxed text-ink-700">{d.description}</p>}
            {!!(d.tags as string[])?.length && (
              <div className="mt-3 flex flex-wrap gap-1">
                {(d.tags as string[]).map((t) => (
                  <Badge key={t} tone="alert">{t}</Badge>
                ))}
              </div>
            )}
          </div>
        </div>

        <hr className="my-5 border-paper-edge" />

        {/* PRD 3.6 wants preview, not a forced download. The browser previews what it
            can in a frame; anything else falls back to the file itself. */}
        {signed?.signedUrl ? (
          <>
            {latest.mime_type === 'application/pdf' || latest.mime_type?.startsWith('image/') ? (
              <iframe
                src={signed.signedUrl}
                title={latest.file_name}
                className="h-[32rem] w-full rounded-xl border border-paper-edge bg-paper"
              />
            ) : (
              <div className="hatch flex h-64 flex-col items-center justify-center rounded-xl border border-paper-edge text-center">
                <FileText size={30} className="text-ink-300" />
                <p className="mt-3 text-sm text-ink-600">{latest.file_name}</p>
                <p className="mt-1 text-xs text-ink-400">
                  This file type cannot be previewed in the browser.
                </p>
              </div>
            )}
            <a
              href={signed.signedUrl}
              download={latest.file_name}
              className="mt-3 inline-flex h-10 items-center gap-2 rounded-full bg-solid px-4.5 text-[13px] font-semibold text-on-solid transition-colors hover:bg-brand-700"
            >
              <Download size={15} />
              Download
            </a>
          </>
        ) : (
          <div className="hatch flex h-64 flex-col items-center justify-center rounded-xl border border-paper-edge text-center">
            <FileText size={30} className="text-ink-300" />
            <p className="mt-3 text-sm text-ink-600">{latest?.file_name ?? 'No file attached'}</p>
            <p className="mt-1 text-xs text-ink-400">
              This record has no file in storage. Upload one from the document library.
            </p>
          </div>
        )}

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
          <ul className="divide-y divide-paper-sunk">
            {versions.map((v) => (
              <li key={v.id} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                <Badge tone={v.version === latest.version ? 'success' : 'neutral'}>v{v.version}</Badge>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm text-ink-700">{v.file_name}</p>
                  <p className="text-xs text-ink-400">
                    {dayTime(v.created_at)}
                    {v.members && ` · ${v.members.full_name}`}
                  </p>
                </div>
                <span className="text-xs text-ink-400">{fileSize(v.size_bytes)}</span>
                {viewer.isStaff && v.version !== latest.version && (
                  <span className="text-xs text-brand-600">Restore</span>
                )}
              </li>
            ))}
          </ul>
        )}
      </Card>
    </article>
  )
}
