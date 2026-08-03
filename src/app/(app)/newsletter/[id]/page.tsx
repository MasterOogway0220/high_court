import Link from 'next/link'
import { notFound } from 'next/navigation'
import { db } from '@/lib/supabase/server'
import { Card } from '@/lib/ui'
import { day } from '@/lib/format'
import { BookOpen } from 'lucide-react'

export const dynamic = 'force-dynamic'

export default async function IssuePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await db()

  const { data: i } = await supabase.from('newsletter_issues').select('*').eq('id', id).maybeSingle()
  if (!i) notFound()

  return (
    <article className="mx-auto max-w-3xl">
      <Link href="/newsletter" className="mb-4 inline-block text-sm text-brand-600 hover:underline">
        ← All issues
      </Link>

      <Card className="p-7">
        <p className="text-[11.5px] font-semibold text-brand-600">{i.issue_no}</p>
        <h1 className="mt-2 font-display text-3xl text-ink-900">{i.title}</h1>
        <p className="mt-1 text-sm text-ink-500">
          {i.period} · published {day(i.published_at)}
        </p>

        {i.editorial && (
          <>
            <hr className="my-5 border-paper-edge" />
            <p className="mb-1 text-xs tracking-wider text-ink-400 uppercase">Editorial note</p>
            <p className="text-[15px] leading-relaxed text-ink-700">{i.editorial}</p>
          </>
        )}

        <hr className="my-5 border-paper-edge" />

        <div className="flex h-96 flex-col items-center justify-center rounded border border-dashed border-paper-edge bg-paper text-center">
          <BookOpen size={32} className="text-ink-200" />
          <p className="mt-3 text-sm text-ink-500">{i.pdf_path?.split('/').pop()}</p>
          <p className="mt-1 max-w-sm text-xs text-ink-400">
            The in-browser reader with page navigation appears here once the issue PDF is uploaded to storage.
          </p>
        </div>

        {i.document_id && (
          <p className="mt-4 text-xs text-ink-400">
            Also filed in the{' '}
            <Link href={`/documents/${i.document_id}`} className="text-brand-600 hover:underline">
              Newsletter Archive
            </Link>{' '}
            of the document library.
          </p>
        )}
      </Card>

      <Card className="mt-4 p-5">
        <h2 className="text-[15px] text-ink-900">Call for contributions</h2>
        <p className="mt-1 text-sm text-ink-500">
          Members are invited to submit articles, case notes and reflections for the next issue. Submissions are
          reviewed by the Editorial Committee.
        </p>
        <Link
          href="/contact?category=general&subject=Newsletter+contribution"
          className="mt-3 inline-block text-sm text-brand-600 hover:underline"
        >
          Submit a contribution →
        </Link>
      </Card>
    </article>
  )
}
