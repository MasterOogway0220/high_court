import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import type { ComponentProps, ReactNode } from 'react'

export const cn = (...c: ClassValue[]) => twMerge(clsx(c))

/*
  Primitives for the court-file direction.

  Surfaces are filed paper, not floating cards: a hairline edge and a flat
  raised tone, no drop shadows. Anything with real interaction complexity uses
  the native element — <select>, <details>, <dialog> — which brings keyboard
  handling and screen-reader semantics without a component library.
*/

const variants = {
  primary: 'bg-ink-900 text-paper-raised hover:bg-ink-800 disabled:bg-ink-300',
  accent: 'bg-rule text-paper-raised hover:bg-[#8f2b24] disabled:bg-rule-soft',
  outline: 'border border-paper-edge bg-paper-raised text-ink-800 hover:border-ink-300 hover:bg-white',
  ghost: 'text-ink-500 hover:bg-paper-sunk hover:text-ink-900',
  danger: 'border border-rule-soft bg-paper-raised text-rule hover:bg-rule-wash',
}

const sizes = {
  sm: 'h-8 px-3 text-[12.5px]',
  md: 'h-9.5 px-4 text-[13.5px]',
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
        'inline-flex items-center justify-center gap-2 rounded-[3px] font-medium transition-colors',
        'disabled:cursor-not-allowed disabled:opacity-70',
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    />
  )
}

/** A sheet of filed paper. Flat, hairline-edged — a document, not a floating card. */
export function Card({ className, ...props }: ComponentProps<'div'>) {
  return (
    <div
      className={cn('rounded-[3px] border border-paper-edge bg-paper-raised', className)}
      {...props}
    />
  )
}

const field =
  'w-full rounded-[3px] border border-paper-edge bg-paper-raised px-3 text-[13.5px] text-ink-900 ' +
  'placeholder:text-ink-300 transition-colors focus:border-ink-500 focus:bg-white focus:outline-none'

export function Input({ className, ...props }: ComponentProps<'input'>) {
  return <input className={cn(field, 'h-9.5', className)} {...props} />
}

export function Select({ className, ...props }: ComponentProps<'select'>) {
  return <select className={cn(field, 'h-9.5 px-2.5', className)} {...props} />
}

export function Textarea({ className, ...props }: ComponentProps<'textarea'>) {
  return <textarea className={cn(field, 'py-2 leading-relaxed', className)} {...props} />
}

export function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="eyebrow mb-1.5 block">{label}</span>
      {children}
      {hint && <span className="mt-1.5 block text-[12px] leading-snug text-ink-400">{hint}</span>}
    </label>
  )
}

const tones = {
  neutral: 'border-paper-edge bg-paper-sunk text-ink-500',
  navy: 'border-ink-200 bg-ink-50 text-ink-700',
  maroon: 'border-rule-soft bg-rule-wash text-rule',
  green: 'border-[#bcd0c2] bg-seal-wash text-seal',
  amber: 'border-[#ddcba4] bg-[#f6efe0] text-[#7a5c1b]',
}

/** Small, squared, uppercase — a stamp on a file, not a pill. */
export function Badge({
  tone = 'neutral',
  className,
  ...props
}: ComponentProps<'span'> & { tone?: keyof typeof tones }) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-[2px] border px-1.5 py-px font-mono text-[10px] tracking-[0.08em] uppercase',
        tones[tone],
        className
      )}
      {...props}
    />
  )
}

/** A record number, date or reference. Monospaced because a register is. */
export function Record({ className, ...props }: ComponentProps<'span'>) {
  return <span className={cn('font-mono text-[12px] text-ink-400', className)} {...props} />
}

/** Page header, set the way a file names its section before its subject. */
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
    <header className="ruled mb-6 flex flex-wrap items-end justify-between gap-4 pb-4">
      <div className="min-w-0">
        {eyebrow && <p className="eyebrow mb-2">{eyebrow}</p>}
        <h1 className="text-[26px] text-ink-900 sm:text-[30px]">{children}</h1>
        {sub && <p className="mt-2 max-w-2xl text-[13.5px] leading-relaxed text-ink-500">{sub}</p>}
      </div>
      {aside && <div className="shrink-0">{aside}</div>}
    </header>
  )
}

/** Section heading inside a page. */
export function SectionTitle({ children, href, label }: { children: ReactNode; href?: string; label?: string }) {
  return (
    <div className="ruled mb-3 flex items-baseline justify-between gap-3 pb-2">
      <h2 className="text-[15px] font-medium text-ink-800">{children}</h2>
      {href && (
        <a href={href} className="font-mono text-[11px] tracking-wide text-rule hover:underline">
          {label ?? 'View all'} →
        </a>
      )}
    </div>
  )
}

/** An empty state is an instruction, never a blank card (PRD 3.1). */
export function Empty({ children }: { children: ReactNode }) {
  return (
    <p className="rounded-[3px] border border-dashed border-paper-edge bg-paper px-4 py-6 text-center text-[13px] text-ink-400">
      {children}
    </p>
  )
}
