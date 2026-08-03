import type { Metadata } from 'next'
import { LoginForm } from './form'

export const metadata: Metadata = { title: 'Sign in' }

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>
}) {
  const { next } = await searchParams

  return (
    <main className="flex min-h-dvh flex-col items-center justify-center bg-ink-900 px-5 py-12">
      <div className="w-full max-w-[26rem]">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-5 flex h-14 w-14 items-center justify-center rounded-full border border-white/25">
            <span className="font-serif text-xl text-white">GH</span>
          </div>
          <h1 className="font-serif text-[1.6rem] leading-tight text-white">
            Guwahati High Court
            <span className="mt-0.5 block text-base font-normal tracking-wide text-white/60">
              Bar Association
            </span>
          </h1>
        </div>

        <div className="rounded-md bg-white p-7 shadow-lg">
          <h2 className="mb-1 text-lg text-ink-900">Member sign in</h2>
          <p className="mb-6 text-[13px] text-ink-400">
            Use your enrolment number or registered mobile number.
          </p>
          <LoginForm next={next ?? '/'} />
        </div>

        <p className="mt-6 text-center text-xs leading-relaxed text-white/40">
          Demo · any seeded account, password <span className="font-mono text-white/70">demo1234</span>
          <br />
          e.g. <span className="font-mono text-white/70">GHC/1995/108</span> (Secretary) ·{' '}
          <span className="font-mono text-white/70">GHC/2010/733</span> (member)
        </p>
      </div>
    </main>
  )
}
