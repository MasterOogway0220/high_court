'use server'

import { redirect } from 'next/navigation'
import { db } from '@/lib/supabase/server'

export async function signIn(_prev: string | null, form: FormData): Promise<string | null> {
  const identifier = String(form.get('identifier') ?? '').trim()
  const password = String(form.get('password') ?? '')
  const next = String(form.get('next') ?? '/') || '/'

  if (!identifier || !password) return 'Enter your enrolment number and password.'

  const supabase = await db()

  // PRD 4.1: members log in with an enrolment number or a registered mobile, neither of
  // which Supabase Auth understands. One resolver, rather than a parallel credential store.
  const { data: email, error: lookupError } = await supabase.rpc('email_for_login', { identifier })

  // A failed lookup and an unknown member are different faults with different fixes.
  // Reporting a broken key or a missing migration as "no member found" sends whoever is
  // debugging it to the wrong place entirely.
  if (lookupError) {
    console.error('[login] email_for_login failed:', lookupError.message)
    return 'Sign-in is unavailable — the directory could not be reached. Contact the Association office.'
  }
  if (!email) return 'No member found with that enrolment number or mobile number.'

  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) return 'That password does not match our records.'

  redirect(next.startsWith('/') ? next : '/')
}

export async function signOut() {
  const supabase = await db()
  await supabase.auth.signOut()
  redirect('/login')
}
