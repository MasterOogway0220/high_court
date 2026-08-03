import { notFound } from 'next/navigation'
import Link from 'next/link'
import { db } from '@/lib/supabase/server'
import { specFor } from '@/lib/records'
import { Card, Heading } from '@/lib/ui'
import { RecordForm } from './form'

export const dynamic = 'force-dynamic'

/*
  One route serves create and edit for every managed table. /manage/announcements/new
  and /manage/announcements/12 are the same screen with a different starting row, so
  there is no reason for them to be different files — or for each table to have its own.
*/

export default async function ManagePage({
  params,
}: {
  params: Promise<{ table: string; id: string }>
}) {
  const { table, id } = await params
  const spec = specFor(table)
  if (!spec) notFound()

  const supabase = await db()

  let row: Record<string, unknown> = {}
  if (id !== 'new') {
    const { data } = await supabase.from(spec.table).select('*').eq('id', id).maybeSingle()
    if (!data) notFound()
    row = data
  }

  // Options that come from the database rather than an enum.
  const options: Record<string, Record<string, string>> = {}
  if (spec.fields.some((f) => f.name === 'folder_id')) {
    const { data: folders } = await supabase.from('folders').select('id, name').order('sort')
    options.folder_id = Object.fromEntries((folders ?? []).map((f) => [String(f.id), f.name]))
  }

  return (
    <div className="mx-auto max-w-3xl">
      <Link href={spec.back} className="mb-5 inline-block font-mono text-[11px] text-brand-600 hover:underline">
        ← {spec.plural}
      </Link>

      <Heading eyebrow={id === 'new' ? 'New record' : `Editing · ${spec.plural}`}>
        {id === 'new' ? `New ${spec.singular.toLowerCase()}` : (row.title as string) || spec.singular}
      </Heading>

      <Card className="p-6 sm:p-7">
        <RecordForm spec={spec} id={id} row={row} options={options} />
      </Card>
    </div>
  )
}
