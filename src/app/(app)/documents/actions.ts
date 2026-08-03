'use server'

import { revalidatePath } from 'next/cache'
import { db, me } from '@/lib/supabase/server'

/*
  The file is already in storage by the time this runs — the browser put it there, to
  stay under Vercel's ~4.5 MB request-body cap (PRD 3.6 asks for 25 MB). This records it.

  Authorisation is left to row-level security: docs_write in 002_rls.sql already says
  who may create a document, and it applies to this connection like any other.
*/
export async function recordUpload(input: {
  title: string
  description: string
  folderId: string
  visibility: string
  filePath: string
  fileName: string
  sizeBytes: number
  mimeType: string
}): Promise<{ error: string } | { id: number }> {
  const member = await me()
  if (!member) return { error: 'Your session has expired. Sign in again.' }
  if (!input.title.trim()) return { error: 'A title is required.' }
  if (!input.filePath) return { error: 'No file was uploaded.' }

  const supabase = await db()

  const { data: doc, error: docError } = await supabase
    .from('documents')
    .insert({
      title: input.title.trim(),
      description: input.description.trim(),
      folder_id: input.folderId ? Number(input.folderId) : null,
      visibility: input.visibility,
      uploader_id: member.id,
    })
    .select('id')
    .single()

  if (docError || !doc) return { error: docError?.message ?? 'The document could not be saved.' }

  const { error: versionError } = await supabase.from('document_versions').insert({
    document_id: doc.id,
    version: 1,
    file_path: input.filePath,
    file_name: input.fileName,
    size_bytes: input.sizeBytes,
    mime_type: input.mimeType,
    uploaded_by: member.id,
  })

  // A document row with no version is a broken record — take it back out rather than
  // leave a file that can never be reached.
  if (versionError) {
    await supabase.from('documents').delete().eq('id', doc.id)
    return { error: versionError.message }
  }

  revalidatePath('/documents')
  return { id: doc.id }
}
