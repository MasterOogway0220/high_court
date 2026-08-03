'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { raiseTicket } from './actions'
import { Button, Field, Input, Select, Textarea } from '@/lib/ui'
import { TICKET_CATEGORY } from '@/lib/format'

function Submit() {
  const { pending } = useFormStatus()
  return (
    <Button type="submit" disabled={pending}>
      {pending ? 'Submitting…' : 'Submit enquiry'}
    </Button>
  )
}

export function ContactForm({
  enrolmentNo,
  defaultCategory,
  defaultSubject,
}: {
  enrolmentNo: string
  defaultCategory?: string
  defaultSubject?: string
}) {
  const [error, action] = useActionState(raiseTicket, null)

  return (
    <form action={action} className="space-y-4">
      {/* honeypot — hidden from people, visible to bots */}
      <input
        type="text"
        name="website"
        tabIndex={-1}
        autoComplete="off"
        aria-hidden
        className="absolute h-0 w-0 overflow-hidden opacity-0"
      />

      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Enrolment number">
          <Input value={enrolmentNo} readOnly className="bg-paper text-ink-500" />
        </Field>
        <Field label="Category">
          <Select name="category" defaultValue={defaultCategory ?? 'general'} required>
            {Object.entries(TICKET_CATEGORY).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </Select>
        </Field>
      </div>

      <Field label="Subject">
        <Input name="subject" defaultValue={defaultSubject} required maxLength={140} placeholder="Briefly, what is this about?" />
      </Field>

      <Field label="Message" hint="Grievances are routed to a restricted queue seen only by designated office bearers.">
        <Textarea name="message" required rows={6} maxLength={5000} placeholder="Describe your enquiry." />
      </Field>

      {error && (
        <p role="alert" className="rounded-xl bg-alert-wash px-3.5 py-2.5 text-[12.5px] font-medium text-alert">
          {error}
        </p>
      )}

      <Submit />
    </form>
  )
}
