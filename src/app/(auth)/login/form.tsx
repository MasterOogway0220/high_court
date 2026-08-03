'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { signIn } from './actions'
import { Button, Field, Input } from '@/lib/ui'

function Submit() {
  const { pending } = useFormStatus()
  return (
    <Button type="submit" size="lg" className="w-full" disabled={pending}>
      {pending ? 'Signing in…' : 'Sign in'}
    </Button>
  )
}

export function LoginForm({ next }: { next: string }) {
  const [error, action] = useActionState(signIn, null)

  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="next" value={next} />

      <Field label="Enrolment number or mobile">
        <Input
          name="identifier"
          autoComplete="username"
          autoFocus
          required
          placeholder="GHC/1995/108"
          aria-invalid={!!error}
        />
      </Field>

      <Field label="Password">
        <Input name="password" type="password" autoComplete="current-password" required aria-invalid={!!error} />
      </Field>

      {error && (
        <p role="alert" className="rounded border border-maroon-200 bg-maroon-50 px-3 py-2 text-[13px] text-maroon-700">
          {error}
        </p>
      )}

      <Submit />

      <p className="pt-1 text-center text-xs text-ink-400">
        First time signing in, or forgotten your password? Contact the Association office.
      </p>
    </form>
  )
}
