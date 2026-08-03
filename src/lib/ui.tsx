import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import type { ComponentProps, ReactNode } from 'react'

export const cn = (...c: ClassValue[]) => twMerge(clsx(c))

// Hand-rolled primitives. Anything with real interaction complexity (dialogs, selects,
// disclosure) uses the native element instead — <dialog>, <select>, <details> — which
// gets keyboard handling and screen-reader semantics without a component library.

const variants = {
  primary: 'bg-ink-900 text-white hover:bg-ink-800 disabled:bg-ink-300',
  accent: 'bg-maroon-700 text-white hover:bg-maroon-600 disabled:bg-maroon-200',
  outline: 'border border-sand-300 bg-white text-ink-800 hover:bg-sand-100',
  ghost: 'text-ink-600 hover:bg-sand-100 hover:text-ink-900',
  danger: 'border border-maroon-200 bg-white text-maroon-700 hover:bg-maroon-50',
}

const sizes = {
  sm: 'h-8 px-3 text-[13px]',
  md: 'h-10 px-4 text-sm',
  lg: 'h-11 px-5 text-[15px]',
}

export function Button({
  variant = 'primary',
  size = 'md',
  className,
  ...props
}: ComponentProps<'button'> & { variant?: keyof typeof variants; size?: keyof typeof sizes }) {
  return (
    <button
      className={cn(
        'inline-flex items-center justify-center gap-2 rounded font-medium transition-colors',
        'disabled:cursor-not-allowed disabled:opacity-70',
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    />
  )
}

export function Card({ className, ...props }: ComponentProps<'div'>) {
  return (
    <div
      className={cn('rounded-md border border-sand-200 bg-white shadow-[0_1px_2px_rgba(22,36,63,0.04)]', className)}
      {...props}
    />
  )
}

export function Input({ className, ...props }: ComponentProps<'input'>) {
  return (
    <input
      className={cn(
        'h-10 w-full rounded border border-sand-300 bg-white px-3 text-sm text-ink-900',
        'placeholder:text-ink-300 focus:border-ink-600 focus:outline-none focus-visible:outline-2',
        className
      )}
      {...props}
    />
  )
}

export function Select({ className, ...props }: ComponentProps<'select'>) {
  return (
    <select
      className={cn(
        'h-10 w-full rounded border border-sand-300 bg-white px-2.5 text-sm text-ink-900',
        'focus:border-ink-600 focus:outline-none',
        className
      )}
      {...props}
    />
  )
}

export function Textarea({ className, ...props }: ComponentProps<'textarea'>) {
  return (
    <textarea
      className={cn(
        'w-full rounded border border-sand-300 bg-white px-3 py-2 text-sm text-ink-900',
        'placeholder:text-ink-300 focus:border-ink-600 focus:outline-none',
        className
      )}
      {...props}
    />
  )
}

export function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-[13px] font-medium text-ink-700">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-ink-400">{hint}</span>}
    </label>
  )
}

const tones = {
  neutral: 'bg-sand-100 text-ink-600 border-sand-300',
  navy: 'bg-ink-50 text-ink-700 border-ink-200',
  maroon: 'bg-maroon-50 text-maroon-700 border-maroon-200',
  green: 'bg-emerald-50 text-emerald-800 border-emerald-200',
  amber: 'bg-amber-50 text-amber-800 border-amber-200',
}

export function Badge({
  tone = 'neutral',
  className,
  ...props
}: ComponentProps<'span'> & { tone?: keyof typeof tones }) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-medium tracking-wide uppercase',
        tones[tone],
        className
      )}
      {...props}
    />
  )
}

/** Section heading with the maroon rule. */
export function Heading({ children, sub }: { children: ReactNode; sub?: string }) {
  return (
    <div className="mb-5">
      <h1 className="rule-accent text-2xl text-ink-900">{children}</h1>
      {sub && <p className="mt-3 max-w-2xl text-sm text-ink-400">{sub}</p>}
    </div>
  )
}

/** Never a blank card (PRD 3.1). */
export function Empty({ children }: { children: ReactNode }) {
  return (
    <p className="rounded border border-dashed border-sand-300 bg-sand-50 px-4 py-6 text-center text-sm text-ink-400">
      {children}
    </p>
  )
}
