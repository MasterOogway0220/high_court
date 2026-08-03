'use server'

import { revalidatePath } from 'next/cache'
import { db, me } from '@/lib/supabase/server'

const CATEGORIES = ['general', 'membership', 'welfare_scheme', 'grievance', 'technical_support', 'other']

export async function raiseTicket(_prev: string | null, form: FormData): Promise<string | null> {
  // honeypot: real members never fill a field they cannot see (PRD 3.9 spam protection)
  if (String(form.get('website') ?? '')) return null

  const member = await me()
  if (!member) return 'Your session has expired. Sign in again.'

  const category = String(form.get('category') ?? 'general')
  const subject = String(form.get('subject') ?? '').trim()
  const message = String(form.get('message') ?? '').trim()

  if (!CATEGORIES.includes(category)) return 'Choose a valid category.'
  if (subject.length < 4) return 'Give the enquiry a subject.'
  if (message.length < 10) return 'Please describe your enquiry in a little more detail.'
  if (message.length > 5000) return 'Please keep the message under 5,000 characters.'

  const supabase = await db()

  // rate limit: 5 tickets per member per hour, counted in the database rather than in memory
  // so it still holds across serverless instances.
  const { count } = await supabase
    .from('tickets')
    .select('id', { count: 'exact', head: true })
    .eq('member_id', member.id)
    .gte('created_at', new Date(Date.now() - 3600_000).toISOString())

  if ((count ?? 0) >= 5) return 'You have opened several enquiries in the past hour. Please try again later.'

  const { error } = await supabase.from('tickets').insert({
    member_id: member.id,
    category,
    subject,
    message,
  })

  if (error) return 'The enquiry could not be submitted. Please try again.'

  revalidatePath('/contact')
  return null
}
