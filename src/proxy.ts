import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

// Next.js 16 renamed `middleware` to `proxy`. Same job: refresh the Supabase session
// cookie on every request so server components never see an expired token, and bounce
// signed-out visitors to /login. Authorisation itself lives in RLS, not here.

const PUBLIC = ['/login', '/activate', '/reset']

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

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { pathname } = request.nextUrl
  const isPublic = PUBLIC.some((p) => pathname.startsWith(p))

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
