'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import Link from 'next/link'
import { saveRecord, deleteRecord } from '../../actions'
import { Button, Field, Input, Select, Textarea } from '@/lib/ui'
import type { RecordSpec } from '@/lib/records'

function Submit({ label }: { label: string }) {
  const { pending } = useFormStatus()
  return (
    <Button type="submit" disabled={pending}>
      {pending ? 'Saving…' : label}
    </Button>
  )
}

/** datetime-local needs `YYYY-MM-DDTHH:mm` in local time, not an ISO string in UTC. */
function forInput(value: unknown, type: string) {
  if (value == null) return ''
  if (type === 'datetime') {
    const d = new Date(String(value))
    if (Number.isNaN(d.getTime())) return ''
    const pad = (n: number) => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
  }
  if (type === 'date') return String(value).slice(0, 10)
  if (type === 'tags') return Array.isArray(value) ? value.join(', ') : String(value)
  return String(value)
}

export function RecordForm({
  spec,
  id,
  row,
  options,
}: {
  spec: RecordSpec
  id: string
  row: Record<string, unknown>
  options: Record<string, Record<string, string>>
}) {
  const isNew = id === 'new'
  const [error, action] = useActionState(saveRecord.bind(null, spec.table, id), null)

  return (
    <>
      <form action={action} className="space-y-5">
        <div className="grid gap-x-5 gap-y-4 sm:grid-cols-2">
          {spec.fields.map((f) => {
            const value = forInput(row[f.name], f.type)
            const opts = f.options && Object.keys(f.options).length ? f.options : options[f.name]

            return (
              <div key={f.name} className={f.full ? 'sm:col-span-2' : ''}>
                {f.type === 'checkbox' ? (
                  <label className="flex items-center gap-2.5 text-[13.5px] text-ink-700">
                    <input
                      type="checkbox"
                      name={f.name}
                      defaultChecked={row[f.name] === true}
                      className="accent-brand-600"
                    />
                    {f.label}
                  </label>
                ) : (
                  <Field label={f.label} hint={f.hint}>
                    {f.type === 'textarea' ? (
                      <Textarea
                        name={f.name}
                        rows={f.rows ?? 4}
                        maxLength={f.max}
                        required={f.required}
                        defaultValue={value}
                      />
                    ) : f.type === 'select' ? (
                      <Select name={f.name} defaultValue={value} required={f.required}>
                        <option value="">—</option>
                        {Object.entries(opts ?? {}).map(([v, l]) => (
                          <option key={v} value={v}>
                            {l}
                          </option>
                        ))}
                      </Select>
                    ) : (
                      <Input
                        name={f.name}
                        type={
                          f.type === 'datetime'
                            ? 'datetime-local'
                            : f.type === 'date'
                              ? 'date'
                              : f.type === 'number'
                                ? 'number'
                                : 'text'
                        }
                        required={f.required}
                        defaultValue={value}
                      />
                    )}
                  </Field>
                )}
              </div>
            )
          })}
        </div>

        {error && (
          <p
            role="alert"
            className="rounded-xl bg-alert-wash px-3.5 py-2.5 text-[12.5px] font-medium text-alert"
          >
            {error}
          </p>
        )}

        <div className="ruled flex items-center gap-3 border-t border-b-0 pt-5">
          <Submit label={isNew ? `Create ${spec.singular.toLowerCase()}` : 'Save changes'} />
          <Link href={spec.back} className="text-[13px] text-ink-500 hover:underline">
            Cancel
          </Link>
        </div>
      </form>

      {!isNew && (
        <form
          action={deleteRecord.bind(null, spec.table, id)}
          className="mt-8 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-alert-wash bg-alert-wash px-4 py-3"
        >
          <p className="text-[12.5px] text-ink-600">
            {spec.softDelete
              ? 'Deleting moves this to the recycle bin. Administrators can restore it for thirty days.'
              : `Deleting this ${spec.singular.toLowerCase()} cannot be undone.`}
          </p>
          <Button variant="danger" size="sm">
            Delete {spec.singular.toLowerCase()}
          </Button>
        </form>
      )}
    </>
  )
}
