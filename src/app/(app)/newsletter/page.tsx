import Link from 'next/link'
import { db } from '@/lib/supabase/server'
import { Card, Empty, Heading } from '@/lib/ui'
import { day } from '@/lib/format'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Newsletter' }

export default async function NewsletterPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; year?: string }>
}) {
  const sp = await searchParams
  const supabase = await db()

  let q = supabase.from('newsletter_issues').select('*').eq('status', 'published')
  if (sp.q?.trim()) q = q.or(`title.ilike.%${sp.q.trim()}%,issue_no.ilike.%${sp.q.trim()}%`)
  if (sp.year) q = q.gte('published_at', `${sp.year}-01-01`).lte('published_at', `${sp.year}-12-31`)

  const { data: issues } = await q.order('published_at', { ascending: false })
  const [latest, ...rest] = issues ?? []

  const years = [...new Set((issues ?? []).map((i) => new Date(i.published_at).getFullYear()))]

  return (
    <>
      <Heading sub="The Gauhati Bar Review — the quarterly journal of the Association.">Newsletter</Heading>

      <form className="mb-5 flex flex-wrap gap-2">
        <input
          name="q"
          defaultValue={sp.q}
          placeholder="Search issues"
          aria-label="Search issues"
          className="h-9 flex-1 rounded border border-sand-300 bg-white px-3 text-sm"
        />
        <select name="year" defaultValue={sp.year ?? ''} aria-label="Year" className="h-9 rounded border border-sand-300 bg-white px-2 text-sm">
          <option value="">All years</option>
          {years.map((y) => (
            <option key={y} value={y}>{y}</option>
          ))}
        </select>
        <button className="h-9 rounded bg-ink-900 px-4 text-sm font-medium text-white">Search</button>
      </form>

      {!issues?.length ? (
        <Empty>No issues have been published yet.</Empty>
      ) : (
        <>
          <Link href={`/newsletter/${latest.id}`}>
            <Card className="mb-6 flex flex-col gap-6 p-6 transition-colors hover:border-ink-200 sm:flex-row">
              <Cover period={latest.period} issue={latest.issue_no} large />
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium tracking-wider text-maroon-700 uppercase">Current issue</p>
                <h2 className="mt-2 font-serif text-2xl text-ink-900">{latest.title}</h2>
                <p className="mt-1 text-sm text-ink-500">
                  {latest.issue_no} · {latest.period}
                </p>
                <p className="mt-3 text-[15px] leading-relaxed text-ink-700">{latest.editorial}</p>
                <p className="mt-4 text-sm text-maroon-700">Read this issue →</p>
              </div>
            </Card>
          </Link>

          {!!rest.length && (
            <>
              <h2 className="mb-3 text-[15px] text-ink-900">Archive</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                {rest.map((i) => (
                  <Link key={i.id} href={`/newsletter/${i.id}`}>
                    <Card className="flex h-full flex-col items-center p-4 text-center transition-colors hover:border-ink-200">
                      <Cover period={i.period} issue={i.issue_no} />
                      <p className="mt-3 font-serif text-sm text-ink-900">{i.period}</p>
                      <p className="mt-0.5 text-xs text-ink-400">{i.issue_no}</p>
                      <p className="mt-1 text-[11px] text-ink-300">{day(i.published_at)}</p>
                    </Card>
                  </Link>
                ))}
              </div>
            </>
          )}
        </>
      )}
    </>
  )
}

function Cover({ period, issue, large }: { period: string | null; issue: string; large?: boolean }) {
  return (
    <div
      className={`flex shrink-0 flex-col items-center justify-center rounded-sm bg-ink-900 px-3 text-center ${
        large ? 'h-52 w-38' : 'h-32 w-24'
      }`}
    >
      <span className={`font-serif text-white/50 ${large ? 'text-[11px]' : 'text-[9px]'}`}>GHCBA</span>
      <span className={`mt-2 font-serif leading-tight text-white ${large ? 'text-base' : 'text-[11px]'}`}>
        The Gauhati Bar Review
      </span>
      <span className={`my-2 h-px bg-maroon-600 ${large ? 'w-10' : 'w-6'}`} />
      <span className={`font-serif text-white/70 ${large ? 'text-xs' : 'text-[9px]'}`}>{period}</span>
      <span className={`mt-0.5 font-serif text-white/40 ${large ? 'text-[10px]' : 'text-[8px]'}`}>{issue}</span>
    </div>
  )
}
