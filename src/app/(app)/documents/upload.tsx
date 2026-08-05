'use client'

import { useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Upload, X } from 'lucide-react'
import { supabase } from '@/lib/supabase/client'
import { Button, Card, Field, Input, Select, Textarea } from '@/lib/ui'
import { VISIBILITY, fileSize } from '@/lib/format'
import { recordUpload } from './actions'

const MAX_BYTES = 25 * 1024 * 1024 // PRD 3.6

/** Strip anything that would make a storage key awkward, keep the extension. */
const safeName = (name: string) =>
  name.replace(/[^\w.\- ]+/g, '').replace(/\s+/g, '-').slice(-120) || 'file'

export function UploadDocument({ folders }: { folders: { id: number; name: string }[] }) {
  const router = useRouter()
  const box = useRef<HTMLDetailsElement>(null)
  const [file, setFile] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const form = new FormData(e.currentTarget)
    setError(null)

    if (!file) return setError('Choose a file to upload.')
    if (file.size > MAX_BYTES) {
      return setError(`That file is ${fileSize(file.size)}. The limit is 25 MB.`)
    }

    setBusy(true)
    // The browser uploads straight to Storage; the server only records the result.
    const path = `${crypto.randomUUID()}/${safeName(file.name)}`
    const { error: uploadError } = await supabase.storage
      .from('documents')
      .upload(path, file, { contentType: file.type || 'application/octet-stream' })

    if (uploadError) {
      setBusy(false)
      return setError(uploadError.message)
    }

    const result = await recordUpload({
      title: String(form.get('title') ?? ''),
      description: String(form.get('description') ?? ''),
      folderId: String(form.get('folder_id') ?? ''),
      visibility: String(form.get('visibility') ?? 'all_members'),
      filePath: path,
      fileName: file.name,
      sizeBytes: file.size,
      mimeType: file.type || 'application/octet-stream',
    })

    if ('error' in result) {
      // Do not leave a file nothing points at.
      await supabase.storage.from('documents').remove([path])
      setBusy(false)
      return setError(result.error)
    }

    setBusy(false)
    setFile(null)
    if (box.current) box.current.open = false
    router.push(`/documents/${result.id}`)
  }

  return (
    <details ref={box} className="mb-4 group">
      <summary className="inline-flex h-10 cursor-pointer list-none items-center gap-2 rounded-full bg-solid px-4.5 text-[13px] font-semibold text-on-solid transition-colors hover:bg-brand-700">
        <Upload size={15} />
        Upload a document
      </summary>

      <Card className="mt-3 p-5">
        <form onSubmit={submit} className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <Field label="Title">
                <Input name="title" required placeholder="Minutes of the Executive Committee" />
              </Field>
            </div>

            <Field label="Folder">
              <Select name="folder_id" defaultValue="">
                <option value="">Uncategorised</option>
                {folders.map((f) => (
                  <option key={f.id} value={f.id}>
                    {f.name}
                  </option>
                ))}
              </Select>
            </Field>

            <Field
              label="Visible to"
              hint="Restricted documents never appear in listings or searches for members outside that group."
            >
              <Select name="visibility" defaultValue="all_members">
                {Object.entries(VISIBILITY).map(([v, l]) => (
                  <option key={v} value={v}>
                    {l}
                  </option>
                ))}
              </Select>
            </Field>

            <div className="sm:col-span-2">
              <Field label="Description" hint="Optional.">
                <Textarea name="description" rows={3} />
              </Field>
            </div>

            <div className="sm:col-span-2">
              <Field label="File" hint="Up to 25 MB.">
                {file ? (
                  <div className="flex items-center gap-3 rounded-lg border border-paper-edge bg-paper px-3.5 py-2.5">
                    <span className="min-w-0 flex-1 truncate text-[13px] text-ink-800">{file.name}</span>
                    <span className="shrink-0 text-[11.5px] text-ink-400 tabular-nums">
                      {fileSize(file.size)}
                    </span>
                    <button
                      type="button"
                      onClick={() => setFile(null)}
                      aria-label="Remove the chosen file"
                      className="shrink-0 rounded p-1 text-ink-400 hover:bg-paper-sunk hover:text-ink-900"
                    >
                      <X size={14} />
                    </button>
                  </div>
                ) : (
                  <input
                    type="file"
                    required
                    onChange={(e) => setFile(e.target.files?.[0] ?? null)}
                    className="w-full cursor-pointer rounded-lg border border-dashed border-paper-edge bg-paper px-3.5 py-3 text-[13px] text-ink-600 file:mr-3 file:rounded-md file:border-0 file:bg-brand-400 file:px-3 file:py-1.5 file:text-[12.5px] file:font-semibold file:text-ink-900"
                  />
                )}
              </Field>
            </div>
          </div>

          {error && (
            <p role="alert" className="rounded-lg bg-alert-wash px-3.5 py-2.5 text-[12.5px] font-medium text-alert">
              {error}
            </p>
          )}

          <Button type="submit" disabled={busy}>
            {busy ? 'Uploading…' : 'Upload document'}
          </Button>
        </form>
      </Card>
    </details>
  )
}
