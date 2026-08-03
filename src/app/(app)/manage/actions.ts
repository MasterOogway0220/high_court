'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { db, me } from '@/lib/supabase/server'
import { specFor } from '@/lib/records'

/*
  One save and one delete for every managed table.

  Authorisation is left to row-level security. The policies in 002_rls.sql already say
  who may write to each table, and they apply to this connection like any other, so a
  member without the standing simply gets an error back from Postgres. Re-checking roles
  here would be a second copy of the rule that could drift from the first.

  What this file must do, because RLS cannot, is bound WHICH columns a form may set.
  Without that whitelist a crafted post could set download_count, or reassign a foreign
  key, or overwrite an id.
*/

function coerce(type: string, raw: FormDataEntryValue | null) {
  const v = typeof raw === 'string' ? raw.trim() : ''
  switch (type) {
    case 'checkbox':
      return raw === 'on' || raw === 'true'
    case 'number':
      return v === '' ? null : Number(v)
    case 'tags':
      return v === '' ? [] : v.split(',').map((s) => s.trim()).filter(Boolean)
    case 'date':
    case 'datetime':
      return v === '' ? null : new Date(v).toISOString()
    default:
      return v === '' ? null : v
  }
}

export async function saveRecord(
  table: string,
  id: string,
  _prev: string | null,
  form: FormData
): Promise<string | null> {
  const spec = specFor(table)
  if (!spec) return 'Unknown record type.'

  const member = await me()
  if (!member) return 'Your session has expired. Sign in again.'

  const row: Record<string, unknown> = {}
  for (const f of spec.fields) {
    // A checkbox that is off sends nothing at all, so it cannot be skipped on absence.
    if (f.type !== 'checkbox' && !form.has(f.name)) continue
    const value = coerce(f.type, form.get(f.name))
    if (f.required && (value === null || value === '')) return `${f.label} is required.`
    row[f.name] = value
  }

  if (!Object.keys(row).length) return 'Nothing to save.'

  const supabase = await db()
  const isNew = id === 'new'

  // On create, an empty field must fall through to the column default — several of these
  // columns are NOT NULL DEFAULT now(), and sending an explicit null rejects the insert.
  // On update the null is kept, because clearing a field is a real edit.
  if (isNew) {
    for (const [k, v] of Object.entries(row)) if (v === null) delete row[k]
  }

  if (isNew && table === 'announcements') row.author_id = member.id
  if (isNew && table === 'events') row.organiser_id = member.id
  if (isNew && table === 'documents') row.uploader_id = member.id

  const { error } = isNew
    ? await supabase.from(table).insert(row)
    : await supabase.from(table).update(row).eq('id', id)

  if (error) {
    // An RLS refusal arrives as an ordinary error; say what it means rather than
    // showing the member a Postgres code.
    if (/row-level security|permission denied/i.test(error.message)) {
      return 'You do not have permission to make this change.'
    }
    return error.message
  }

  revalidatePath(spec.back)
  revalidatePath('/')
  redirect(spec.back)
}

export async function deleteRecord(table: string, id: string) {
  const spec = specFor(table)
  if (!spec) return

  const supabase = await db()

  // PRD 3.6: deleting a document is reversible for thirty days, so it is a soft delete.
  const { error } = spec.softDelete
    ? await supabase.from(table).update({ deleted_at: new Date().toISOString() }).eq('id', id)
    : await supabase.from(table).delete().eq('id', id)

  if (error) throw new Error(error.message)

  revalidatePath(spec.back)
  revalidatePath('/')
  redirect(spec.back)
}

export async function restoreDocument(id: string) {
  const supabase = await db()
  await supabase.from('documents').update({ deleted_at: null }).eq('id', id)
  revalidatePath('/documents')
}

/** Admin: move an enquiry along without opening the full form. */
export async function setTicketStatus(id: string, status: string) {
  const supabase = await db()
  await supabase.from('tickets').update({ status, updated_at: new Date().toISOString() }).eq('id', id)
  revalidatePath('/admin')
  revalidatePath('/contact')
}

/** Admin: act on a member's requested profile change (PRD 3.2 moderation queue). */
export async function reviewProfileChange(id: string, approve: boolean) {
  const supabase = await db()
  const member = await me()
  if (!member) return

  const { data: change } = await supabase
    .from('member_profile_changes')
    .select('member_id, field, new_value')
    .eq('id', id)
    .maybeSingle()

  if (change && approve) {
    await supabase
      .from('members')
      .update({ [change.field]: change.new_value })
      .eq('id', change.member_id)
  }

  await supabase
    .from('member_profile_changes')
    .update({
      status: approve ? 'approved' : 'rejected',
      reviewed_by: member.id,
      reviewed_at: new Date().toISOString(),
    })
    .eq('id', id)

  revalidatePath('/admin')
  revalidatePath('/directory')
}
