import Link from 'next/link'
import { db, me } from '@/lib/supabase/server'
import { Badge, Card, Empty, Heading, Input } from '@/lib/ui'
import { VISIBILITY, day, fileSize } from '@/lib/format'
import { FileText, Folder as FolderIcon, Download } from 'lucide-react'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Document Library' }

export default async function DocumentsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; folder?: string }>
}) {
  const sp = await searchParams
  const supabase = await db()
  const viewer = (await me())!

  const { data: folders } = await supabase.from('folders').select('*').is('parent_id', null).order('sort')

  let query = supabase
    .from('documents')
    .select('id, title, description, tags, visibility, download_count, created_at, folder_id, folders(name), document_versions(version, size_bytes, file_name)')
    .is('deleted_at', null)

  if (sp.q?.trim()) {
    const q = sp.q.trim()
    query = query.or(`title.ilike.%${q}%,description.ilike.%${q}%`)
  }
  if (sp.folder) query = query.eq('folder_id', sp.folder)

  const { data: docs } = await query.order('created_at', { ascending: false }).limit(100)

  return (
    <>
      <Heading sub="Constitution, circulars, minutes, forms and association records.">Document Library</Heading>

      <div className="grid gap-4 lg:grid-cols-[15rem_1fr]">
        <aside>
          <Card className="p-3">
            <p className="px-2 pb-2 text-xs tracking-wider text-ink-400 uppercase">Folders</p>
            <ul className="space-y-0.5">
              <li>
                <Link
                  href="/documents"
                  className={`block rounded px-2 py-1.5 text-sm ${!sp.folder ? 'bg-sand-100 font-medium text-ink-900' : 'text-ink-600 hover:bg-sand-50'}`}
                >
                  All documents
                </Link>
              </li>
              {folders?.map((f) => (
                <li key={f.id}>
                  <Link
                    href={`/documents?folder=${f.id}`}
                    className={`flex items-center gap-2 rounded px-2 py-1.5 text-sm ${
                      sp.folder === String(f.id) ? 'bg-sand-100 font-medium text-ink-900' : 'text-ink-600 hover:bg-sand-50'
                    }`}
                  >
                    <FolderIcon size={14} className="shrink-0 text-ink-300" />
                    <span className="truncate">{f.name}</span>
                  </Link>
                </li>
              ))}
            </ul>
          </Card>
        </aside>

        <div>
          <form className="mb-4">
            <Input name="q" defaultValue={sp.q} placeholder="Search by title, description or tag" aria-label="Search documents" />
            {sp.folder && <input type="hidden" name="folder" value={sp.folder} />}
          </form>

          {!docs?.length ? (
            <Empty>No documents match. Note that some documents are restricted to committee members.</Empty>
          ) : (
            <ul className="space-y-2">
              {docs.map((d) => {
                const v = ((d.document_versions ?? []) as any[]).sort((a, b) => b.version - a.version)[0]
                return (
                  <li key={d.id}>
                    <Link href={`/documents/${d.id}`}>
                      <Card className="flex items-start gap-3 p-4 transition-colors hover:border-ink-200">
                        <FileText size={18} className="mt-0.5 shrink-0 text-ink-300" />
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-1.5">
                            <p className="text-sm font-medium text-ink-900">{d.title}</p>
                            {d.visibility !== 'all_members' && (
                              <Badge tone="amber">{VISIBILITY[d.visibility]}</Badge>
                            )}
                            {v?.version > 1 && <Badge>v{v.version}</Badge>}
                          </div>
                          {d.description && (
                            <p className="mt-0.5 line-clamp-1 text-sm text-ink-500">{d.description}</p>
                          )}
                          <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-ink-400">
                            <span>{(d.folders as any)?.name}</span>
                            <span>{day(d.created_at)}</span>
                            <span>{fileSize(v?.size_bytes)}</span>
                            {viewer.isStaff && (
                              <span className="flex items-center gap-1">
                                <Download size={11} /> {d.download_count}
                              </span>
                            )}
                          </div>
                          {!!(d.tags as string[])?.length && (
                            <div className="mt-2 flex flex-wrap gap-1">
                              {(d.tags as string[]).slice(0, 4).map((t) => (
                                <Badge key={t}>{t}</Badge>
                              ))}
                            </div>
                          )}
                        </div>
                      </Card>
                    </Link>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      </div>
    </>
  )
}
