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
    <main className="flex min-h-dvh flex-col justify-center bg-ink-900 px-5 py-12">
      <div className="mx-auto w-full max-w-[24rem]">
        {/* A title page: the institution named in full, then the instrument. */}
        <div className="mb-9 text-center">
          <div className="mx-auto mb-6 flex h-12 w-12 items-center justify-center rounded-[2px] border border-white/25 font-display text-[15px] text-white">
            GH
          </div>
          <h1 className="font-display text-[26px] leading-tight text-white">
            Guwahati High Court
          </h1>
          <p className="mt-2 font-mono text-[10px] tracking-[0.26em] text-white/45 uppercase">
            Bar Association
          </p>
          <div className="mx-auto mt-5 h-px w-10 bg-rule" />
        </div>

        <div className="rounded-[3px] bg-paper-raised p-7">
          <p className="eyebrow">Member access</p>
          <h2 className="mt-1.5 font-display text-[19px] text-ink-900">Sign in</h2>
          <p className="mt-1.5 mb-6 text-[12.5px] leading-relaxed text-ink-500">
            Use your enrolment number or the mobile number on the roll.
          </p>
          <LoginForm next={next ?? '/'} />
        </div>

        <div className="mt-7 rounded-[3px] border border-white/12 px-4 py-3 text-center">
          <p className="font-mono text-[9.5px] tracking-[0.18em] text-white/35 uppercase">
            Demonstration
          </p>
          <p className="mt-1.5 font-mono text-[11px] leading-relaxed text-white/55">
            GHC/1995/108 · demo1234
          </p>
        </div>
      </div>
    </main>
  )
}
