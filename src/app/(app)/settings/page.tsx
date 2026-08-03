import { revalidatePath } from 'next/cache'
import { randomUUID } from 'node:crypto'
import { db, me } from '@/lib/supabase/server'
import { Badge, Button, Card, Field, Heading, Input, Textarea } from '@/lib/ui'
import { CATEGORY } from '@/lib/format'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Settings' }

// PRD 3.2: contact details, bio, practice areas and photo are self-service.
// Name, enrolment number and designation go to a moderation queue instead.
const MODERATED = ['full_name', 'enrolment_no', 'designation'] as const

async function saveProfile(form: FormData) {
  'use server'
  const member = await me()
  if (!member) return
  const supabase = await db()

  await supabase
    .from('members')
    .update({
      chamber_address: String(form.get('chamber_address') ?? '').trim() || null,
      chamber_phone: String(form.get('chamber_phone') ?? '').trim() || null,
      mobile: String(form.get('mobile') ?? '').trim() || null,
      bio: String(form.get('bio') ?? '').trim().slice(0, 500) || null,
      practice_areas: String(form.get('practice_areas') ?? '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
      hide_mobile: form.get('hide_mobile') === 'on',
      hide_email: form.get('hide_email') === 'on',
    })
    .eq('id', member.id)

  // moderated fields never write straight through
  for (const field of MODERATED) {
    const next = String(form.get(field) ?? '').trim()
    const current = String((member as Record<string, unknown>)[field] ?? '')
    if (next && next !== current) {
      await supabase.from('member_profile_changes').insert({
        member_id: member.id,
        field,
        old_value: current,
        new_value: next,
      })
    }
  }

  revalidatePath('/settings')
}

async function rotateIcsToken() {
  'use server'
  const member = await me()
  if (!member) return
  const supabase = await db()
  await supabase.from('ics_tokens').update({ revoked: true }).eq('member_id', member.id)
  await supabase.from('ics_tokens').insert({ token: randomUUID().replace(/-/g, ''), member_id: member.id })
  revalidatePath('/settings')
}

export default async function SettingsPage() {
  const member = (await me())!
  const supabase = await db()

  const { data: token } = await supabase
    .from('ics_tokens')
    .select('token')
    .eq('revoked', false)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  const { data: prefs } = await supabase.from('notification_prefs').select('*')
  const enabled = (c: string) => prefs?.find((p) => p.category === c)?.email_enabled ?? true

  return (
    <>
      <Heading sub="Your profile, privacy and notification preferences.">Settings</Heading>

      {/* Two tracks: what you edit on the left, what the account exposes on the right.
          The calendar feed keeps its own form, so it cannot sit inside this one. */}
      <div className="grid items-start gap-3.5 xl:grid-cols-3">
      <form action={saveProfile} className="space-y-3.5 xl:col-span-2">
        <Card className="p-6">
          <h2 className="mb-4 text-[15px] text-ink-900">Profile</h2>
          <div className="grid gap-4 sm:grid-cols-2 2xl:grid-cols-3">
            <Field label="Full name" hint="Changes require approval by the Association office.">
              <Input name="full_name" defaultValue={member.full_name} />
            </Field>
            <Field label="Enrolment number" hint="Changes require approval.">
              <Input name="enrolment_no" defaultValue={member.enrolment_no} />
            </Field>
            <Field label="Mobile">
              <Input name="mobile" defaultValue={member.mobile ?? ''} />
            </Field>
            <Field label="Chamber phone">
              <Input name="chamber_phone" defaultValue={member.chamber_phone ?? ''} />
            </Field>
            <div className="sm:col-span-2 2xl:col-span-3">
              <Field label="Chamber address">
                <Input name="chamber_address" defaultValue={member.chamber_address ?? ''} />
              </Field>
            </div>
            <div className="sm:col-span-2 2xl:col-span-3">
              <Field label="Practice areas" hint="Separate with commas.">
                <Input name="practice_areas" defaultValue={(member.practice_areas as string[])?.join(', ')} />
              </Field>
            </div>
            <div className="sm:col-span-2 2xl:col-span-3">
              <Field label="Short bio" hint="Up to 500 characters.">
                <Textarea name="bio" rows={4} maxLength={500} defaultValue={member.bio ?? ''} />
              </Field>
            </div>
          </div>
        </Card>

        <div className="grid gap-3.5 md:grid-cols-2">
        <Card className="p-6">
          <h2 className="mb-1 text-[15px] text-ink-900">Privacy</h2>
          <p className="mb-4 text-sm text-ink-400">
            Office bearers can always see your full contact details.
          </p>
          <div className="space-y-3">
            <label className="flex items-center gap-2.5 text-sm text-ink-700">
              <input type="checkbox" name="hide_mobile" defaultChecked={member.hide_mobile} className="accent-brand-600" />
              Hide my mobile number from other members
            </label>
            <label className="flex items-center gap-2.5 text-sm text-ink-700">
              <input type="checkbox" name="hide_email" defaultChecked={member.hide_email} className="accent-brand-600" />
              Hide my email address from other members
            </label>
          </div>
        </Card>

        <Card className="p-6">
          <h2 className="mb-1 text-[15px] text-ink-900">Email notifications</h2>
          <p className="mb-4 text-sm text-ink-400">
            Urgent announcements are always sent and cannot be switched off.
          </p>
          <div className="space-y-3">
            {Object.entries(CATEGORY).map(([v, l]) => (
              <label key={v} className="flex items-center gap-2.5 text-sm text-ink-700">
                <input
                  type="checkbox"
                  name={`pref_${v}`}
                  defaultChecked={v === 'urgent' ? true : enabled(v)}
                  disabled={v === 'urgent'}
                  className="accent-brand-600 disabled:opacity-50"
                />
                {l}
                {v === 'urgent' && <Badge tone="alert">Always on</Badge>}
              </label>
            ))}
          </div>
        </Card>
        </div>

        <Button type="submit">Save changes</Button>
      </form>

      <Card className="p-6">
        <h2 className="mb-1 text-[15px] text-ink-900">Calendar subscription</h2>
        <p className="mb-4 text-sm text-ink-400">
          A private feed of your association calendar for Google or Outlook. Anyone with this link can read your
          calendar — rotate it if it is ever shared by accident.
        </p>
        {token ? (
          <code className="block overflow-x-auto rounded-lg border border-paper-edge bg-paper px-3 py-2 text-xs break-all text-ink-600">
            /api/ics/{token.token}
          </code>
        ) : (
          <p className="text-sm text-ink-400">No feed link has been generated yet.</p>
        )}
        <form action={rotateIcsToken} className="mt-3">
          <Button variant="outline" size="sm">
            {token ? 'Revoke and generate a new link' : 'Generate feed link'}
          </Button>
        </form>
      </Card>
      </div>
    </>
  )
}
