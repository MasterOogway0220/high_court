import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

// Next.js 16 renamed `middleware` to `proxy`. Same job: refresh the Supabase session
// cookie on every request so server components never see an expired token.
//
// DEMO_AUTO_LOGIN: when set, an anonymous visitor is signed in automatically as that
// account instead of being sent to /login. This exists so the dashboard can be shown
// without a sign-in step while roles are not yet in use.
//
// It is deliberately gated on an env var rather than hard-coded: leave it unset and the
// normal sign-in gate returns, with no code change. Never set it in production — it hands
// every visitor a full session.

const PUBLIC = ['/login', '/activate', '/reset']
const DEMO = process.env.DEMO_AUTO_LOGIN
const DEMO_PASSWORD = process.env.DEMO_AUTO_LOGIN_PASSWORD ?? 'demo1234'

export async function proxy(request: NextRequest) {
  const response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll(list) {
          for (const { name, value, options } of list) {
            response.cookies.set(name, value, options)
          }
        },
      },
    }
  )

  let {
    data: { user },
  } = await supabase.auth.getUser()

  const { pathname } = request.nextUrl

  if (!user && DEMO) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: DEMO,
      password: DEMO_PASSWORD,
    })
    if (error) {
      // Fail loudly in the log rather than silently bouncing to a login page the
      // operator has deliberately turned off.
      console.error(`[proxy] demo auto-login as ${DEMO} failed: ${error.message}`)
    } else {
      user = data.user
    }
    // The sign-in wrote session cookies onto `response`; send the visitor back to the
    // same URL so the request re-runs with a session attached.
    if (user) return NextResponse.redirect(request.nextUrl, { headers: response.headers })
  }

  const isPublic = PUBLIC.some((p) => pathname.startsWith(p))

  // Only skip past /login once a session actually exists. Redirecting away from the
  // login page purely because demo mode is configured means a failed auto-login
  // bounces between / and /login forever, which the browser reports as
  // ERR_TOO_MANY_REDIRECTS rather than as the sign-in failure it is.
  if (DEMO && user && isPublic) {
    const to = request.nextUrl.clone()
    to.pathname = '/'
    to.searchParams.delete('next')
    return NextResponse.redirect(to)
  }

  if (!user && !isPublic) {
    const to = request.nextUrl.clone()
    to.pathname = '/login'
    to.searchParams.set('next', pathname)
    return NextResponse.redirect(to)
  }

  if (user && pathname === '/login') {
    const to = request.nextUrl.clone()
    to.pathname = '/'
    to.searchParams.delete('next')
    return NextResponse.redirect(to)
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api/ics|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)'],
}
