import type { Metadata } from 'next'
import { Scale } from 'lucide-react'
import { LoginForm } from './form'

export const metadata: Metadata = { title: 'Sign in' }

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>
}) {
  const { next } = await searchParams

  return (
    <main className="flex min-h-dvh flex-col justify-center px-5 py-12">
      <div className="mx-auto w-full max-w-[25rem]">
        <div className="mb-6 flex items-center gap-2.5">
          <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-solid text-on-solid">
            <Scale size={19} />
          </span>
          <span className="leading-none">
            <span className="block text-[18px] font-extrabold tracking-tight text-ink-900">GHCBA</span>
            <span className="mt-1 block text-[11px] text-ink-400">
              Guwahati High Court Bar Association
            </span>
          </span>
        </div>

        <div className="rounded-panel border border-paper-edge bg-paper-raised p-7">
          <h1 className="text-[22px] text-ink-900">Sign in</h1>
          <p className="mt-1.5 mb-6 text-[13px] text-ink-400">
            Use your enrolment number or the mobile number on the roll.
          </p>
          <LoginForm next={next ?? '/'} />
        </div>

        <div className="mt-4 flex flex-wrap items-center justify-center gap-2 rounded-2xl bg-paper-sunk px-4 py-3">
          <span className="eyebrow">Demo</span>
          <span className="text-[12.5px] text-ink-500 tabular-nums">GHC/1995/108 · demo1234</span>
        </div>
      </div>
    </main>
  )
}
