'use client'

import { useOptimistic, useState, useTransition } from 'react'
import { supabase } from '@/lib/supabase/client'
import { Button, Select } from '@/lib/ui'

type Status = 'attending' | 'not_attending' | 'maybe'

const CHOICES: [Status, string][] = [
  ['attending', 'Attending'],
  ['maybe', 'Maybe'],
  ['not_attending', 'Not attending'],
]

/** PRD 3.5: RSVP updates optimistically and reconciles on server confirmation. */
export function Rsvp({
  eventId,
  initial,
  initialGuests,
  waitlisted,
  allowGuests,
  closed,
}: {
  eventId: number
  initial: Status | null
  initialGuests: number
  waitlisted: boolean
  allowGuests: boolean
  closed: boolean
}) {
  const [saved, setSaved] = useState<{ status: Status | null; waitlisted: boolean }>({
    status: initial,
    waitlisted,
  })
  const [guests, setGuests] = useState(initialGuests)
  const [error, setError] = useState<string | null>(null)
  const [pending, start] = useTransition()
  const [optimistic, setOptimistic] = useOptimistic(saved)

  function choose(status: Status) {
    setError(null)
    start(async () => {
      setOptimistic({ status, waitlisted: false })
      const { data, error } = await supabase.rpc('rsvp_set', {
        p_event: eventId,
        p_status: status,
        p_guests: status === 'attending' ? guests : 0,
      })
      if (error) {
        setError(error.message)
        return
      }
      const row = (data as { status: Status; waitlisted: boolean }[])?.[0]
      setSaved({ status: row?.status ?? status, waitlisted: row?.waitlisted ?? false })
    })
  }

  if (closed) {
    return (
      <p className="rounded border border-paper-edge bg-paper-sunk px-4 py-3 text-sm text-ink-500">
        RSVP for this event has closed.
      </p>
    )
  }

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {CHOICES.map(([value, label]) => (
          <Button
            key={value}
            onClick={() => choose(value)}
            disabled={pending}
            variant={optimistic.status === value ? (value === 'attending' ? 'accent' : 'primary') : 'outline'}
            size="sm"
          >
            {label}
          </Button>
        ))}
      </div>

      {allowGuests && optimistic.status === 'attending' && (
        <label className="flex items-center gap-2 text-sm text-ink-600">
          Accompanying persons
          <Select
            value={guests}
            onChange={(e) => {
              const n = Number(e.target.value)
              setGuests(n)
              start(async () => {
                await supabase.rpc('rsvp_set', { p_event: eventId, p_status: 'attending', p_guests: n })
              })
            }}
            className="h-8 w-20"
          >
            {[0, 1, 2, 3, 4].map((n) => (
              <option key={n} value={n}>{n}</option>
            ))}
          </Select>
        </label>
      )}

      {optimistic.waitlisted && (
        <p className="rounded border border-amber-200 bg-amber-50 px-3 py-2 text-[13px] text-amber-900">
          This event is full — you are on the waitlist and will be confirmed automatically if a place opens.
        </p>
      )}

      {error && (
        <p role="alert" className="rounded-xl bg-alert-wash px-3.5 py-2.5 text-[12.5px] font-medium text-alert">
          {error}
        </p>
      )}
    </div>
  )
}
