import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import type { ComponentProps, ReactNode } from 'react'

export const cn = (...c: ClassValue[]) => twMerge(clsx(c))

/*
  Primitives.

  Surfaces are white cards with a hairline edge and a 16px radius; controls carry a
  small 8px radius; status reads as a soft tinted chip. Anything with real interaction
  complexity uses the native element — <select>, <details>, <dialog> — which brings
  keyboard handling and screen-reader semantics without a component library.
*/

const variants = {
  primary: 'bg-brand-600 text-white hover:bg-brand-700 disabled:bg-ink-300',
  accent: 'bg-brand-400 text-ink-900 hover:bg-brand-500 disabled:bg-brand-200',
  outline: 'border border-paper-edge bg-white text-ink-800 hover:border-ink-300 hover:bg-paper-sunk',
  ghost: 'text-ink-500 hover:bg-paper-sunk hover:text-ink-900',
  danger: 'border border-alert-wash bg-alert-wash text-alert hover:bg-alert hover:text-white',
}

const sizes = {
  sm: 'h-8 px-3.5 text-[12.5px]',
  md: 'h-10 px-4.5 text-[13px]',
  lg: 'h-12 px-6 text-[14px]',
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
        'inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition-colors',
        'disabled:cursor-not-allowed disabled:opacity-70',
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    />
  )
}

/** A card. White, hairline-edged, 16px radius — the unit the whole dashboard is built from. */
export function Card({ className, ...props }: ComponentProps<'div'>) {
  return (
    <div
      className={cn('rounded-card border border-paper-edge bg-paper-raised', className)}
      {...props}
    />
  )
}

const field =
  'w-full rounded-lg border border-paper-edge bg-white px-3.5 text-[13px] text-ink-900 ' +
  'placeholder:text-ink-300 transition-colors focus:border-brand-400 focus:outline-none'

export function Input({ className, ...props }: ComponentProps<'input'>) {
  return <input className={cn(field, 'h-10', className)} {...props} />
}

export function Select({ className, ...props }: ComponentProps<'select'>) {
  return <select className={cn(field, 'h-10 px-3', className)} {...props} />
}

export function Textarea({ className, ...props }: ComponentProps<'textarea'>) {
  return <textarea className={cn(field, 'py-2.5 leading-relaxed', className)} {...props} />
}

export function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-[12.5px] font-semibold text-ink-700">{label}</span>
      {children}
      {hint && <span className="mt-1.5 block text-[12px] leading-snug text-ink-400">{hint}</span>}
    </label>
  )
}

const tones = {
  neutral: 'bg-paper-sunk text-ink-500',
  info: 'bg-info-wash text-info',
  alert: 'bg-alert-wash text-alert',
  success: 'bg-brand-50 text-brand-600',
  warn: 'bg-warn-wash text-warn',
}

/** A soft tinted chip, as the reference marks task status. */
export function Badge({
  tone = 'neutral',
  className,
  ...props
}: ComponentProps<'span'> & { tone?: keyof typeof tones }) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-md px-2 py-0.5 text-[10.5px] font-semibold capitalize',
        tones[tone],
        className
      )}
      {...props}
    />
  )
}

/** A record number, date or reference. Tabular so figures line up down a column. */
export function Record({ className, ...props }: ComponentProps<'span'>) {
  return (
    <span
      className={cn('text-[11.5px] text-ink-400 tabular-nums', className)}
      {...props}
    />
  )
}

/** Page header: title, one line of purpose, actions on the right. */
export function Heading({
  children,
  sub,
  eyebrow,
  aside,
}: {
  children: ReactNode
  sub?: string
  eyebrow?: string
  aside?: ReactNode
}) {
  return (
    <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {eyebrow && <p className="eyebrow mb-2">{eyebrow}</p>}
        <h1 className="text-[26px] text-ink-900 sm:text-[30px]">{children}</h1>
        {sub && <p className="mt-1.5 max-w-2xl text-[13px] text-ink-400">{sub}</p>}
      </div>
      {aside && <div className="flex shrink-0 items-center gap-2.5">{aside}</div>}
    </header>
  )
}

/** Section heading inside a card. */
export function SectionTitle({ children, href, label }: { children: ReactNode; href?: string; label?: string }) {
  return (
    <div className="mb-3.5 flex items-center justify-between gap-3">
      <h2 className="text-[15px] font-bold text-ink-900">{children}</h2>
      {href && (
        <a
          href={href}
          className="rounded-lg border border-paper-edge px-2.5 py-1 text-[11.5px] font-semibold text-ink-500 transition-colors hover:border-brand-300 hover:text-brand-600"
        >
          {label ?? 'View all'}
        </a>
      )}
    </div>
  )
}

/** An empty state is an instruction, never a blank card (PRD 3.1). Hatched, as the
    reference draws any slot that holds no value yet. */
export function Empty({ children }: { children: ReactNode }) {
  return (
    <p className="hatch rounded-xl border border-paper-edge px-4 py-6 text-center text-[12.5px] text-ink-400">
      {children}
    </p>
  )
}
