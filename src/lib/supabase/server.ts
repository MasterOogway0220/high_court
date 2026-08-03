import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

// Fail with the name of the missing variable. Without this, an unset value reaches
// Supabase as `undefined` and surfaces as a generic fetch or "Invalid API key" error
// that says nothing about configuration — which is the wrong place to start looking.
function required(name: string) {
  const v = process.env[name]
  if (!v) {
    throw new Error(
      `${name} is not set. Add it in Vercel → Project Settings → Environment Variables, ` +
        `or in .env.local for local development.`
    )
  }
  return v
}

const url = required('NEXT_PUBLIC_SUPABASE_URL')
const anon = required('NEXT_PUBLIC_SUPABASE_ANON_KEY')

/** Request-scoped client. RLS applies — this is the only client the app should use. */
export async function db() {
  const jar = await cookies()

  return createServerClient(url, anon, {
    cookies: {
      getAll: () => jar.getAll(),
      setAll(list) {
        // Server Components cannot set cookies; proxy.ts refreshes the session instead.
        try {
          for (const { name, value, options } of list) jar.set(name, value, options)
        } catch {}
      },
    },
  })
}

/** The signed-in member, with roles. null when signed out. */
export async function me() {
  const supabase = await db()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return null

  const [{ data: member }, { data: roles }] = await Promise.all([
    supabase.from('members').select('*').eq('id', user.id).single(),
    supabase.from('member_roles').select('role').eq('member_id', user.id),
  ])
  if (!member) return null

  const list: string[] = (roles ?? []).map((r: { role: string }) => r.role)

  return {
    ...member,
    roles: list,
    canPublish: list.some((r) => ['office_bearer', 'admin', 'super_admin'].includes(r)),
    isStaff: list.some((r) => ['admin', 'super_admin'].includes(r)),
  }
}

export type Me = NonNullable<Awaited<ReturnType<typeof me>>>
