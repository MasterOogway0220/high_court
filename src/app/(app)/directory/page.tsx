import Link from 'next/link'
import { db, me } from '@/lib/supabase/server'
import { Badge, Button, Card, Empty, Heading, Input, Select } from '@/lib/ui'
import { DESIGNATION, day } from '@/lib/format'
import { Search } from 'lucide-react'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Member Directory' }

const PRACTICE_AREAS = [
  'Constitutional', 'Criminal', 'Civil', 'Service', 'Taxation',
  'Family Law', 'Labour', 'Environmental', 'Company', 'Land & Revenue', 'Arbitration',
]

type Search = {
  q?: string; area?: string; designation?: string; status?: string
  from?: string; to?: string; sort?: string; view?: string
}

export default async function DirectoryPage({ searchParams }: { searchParams: Promise<Search> }) {
  const sp = await searchParams
  const supabase = await db()
  const viewer = (await me())!

  let query = supabase
    .from('members')
    .select('id, enrolment_no, full_name, designation, enrolment_date, practice_areas, chamber_address, membership_status, photo_url, mobile, email, hide_mobile, hide_email')

  // PRD 3.2: search across name, enrolment number, practice area, chamber location
  if (sp.q?.trim()) {
    const q = sp.q.trim()
    query = query.or(
      `full_name.ilike.%${q}%,enrolment_no.ilike.%${q}%,chamber_address.ilike.%${q}%`
    )
  }
  if (sp.area) query = query.contains('practice_areas', [sp.area])
  if (sp.designation) query = query.eq('designation', sp.designation)
  if (sp.status) query = query.eq('membership_status', sp.status)
  if (sp.from) query = query.gte('enrolment_date', `${sp.from}-01-01`)
  if (sp.to) query = query.lte('enrolment_date', `${sp.to}-12-31`)

  query =
    sp.sort === 'year'
      ? query.order('enrolment_date', { ascending: true })
      : sp.sort === 'recent'
        ? query.order('enrolment_date', { ascending: false })
        : query.order('full_name', { ascending: true })

  const { data: members, error } = await query.limit(300)
  const cards = sp.view === 'card'

  return (
    <>
      <Heading
        eyebrow="Association record"
        sub="All enrolled members. Contact details respect each member's privacy settings."
        aside={
          viewer.isStaff ? (
            <Link href="/manage/members/new">
              <Button size="sm">Add member</Button>
            </Link>
          ) : null
        }
      >
        Member Directory
      </Heading>

      <Card className="mb-4 p-4">
        <form className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="relative sm:col-span-2">
            <Search size={15} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-ink-300" />
            <Input
              name="q"
              defaultValue={sp.q}
              placeholder="Name, enrolment number, or chamber"
              className="pl-9"
              aria-label="Search members"
            />
          </div>

          <Select name="area" defaultValue={sp.area ?? ''} aria-label="Practice area">
            <option value="">All practice areas</option>
            {PRACTICE_AREAS.map((a) => (
              <option key={a} value={a}>{a}</option>
            ))}
          </Select>

          <Select name="designation" defaultValue={sp.designation ?? ''} aria-label="Designation">
            <option value="">All designations</option>
            {Object.entries(DESIGNATION).map(([v, l]) => (
              <option key={v} value={v}>{l}</option>
            ))}
          </Select>

          <Select name="status" defaultValue={sp.status ?? ''} aria-label="Membership status">
            <option value="">All statuses</option>
            {['active', 'life', 'suspended', 'retired', 'deceased'].map((s) => (
              <option key={s} value={s} className="capitalize">{s}</option>
            ))}
          </Select>

          <div className="flex gap-2">
            <Input name="from" type="number" placeholder="From year" min={1948} max={2100} defaultValue={sp.from} aria-label="Enrolled from year" />
            <Input name="to" type="number" placeholder="To year" min={1948} max={2100} defaultValue={sp.to} aria-label="Enrolled to year" />
          </div>

          <Select name="sort" defaultValue={sp.sort ?? 'name'} aria-label="Sort by">
            <option value="name">Sort: Name (A–Z)</option>
            <option value="year">Sort: Enrolment year</option>
            <option value="recent">Sort: Recently joined</option>
          </Select>

          <div className="flex gap-2">
            <button type="submit" className="h-10 flex-1 rounded bg-ink-900 px-4 text-sm font-medium text-white hover:bg-ink-800">
              Apply
            </button>
            <Link href="/directory" className="flex h-10 items-center rounded border border-paper-edge px-3 text-sm text-ink-600 hover:bg-paper-sunk">
              Clear
            </Link>
          </div>

          {/* list on desktop, cards on mobile — toggle persists via the query string (PRD 3.2) */}
          <input type="hidden" name="view" value={sp.view ?? ''} />
        </form>
      </Card>

      <div className="mb-3 flex items-center justify-between">
        <p className="text-sm text-ink-400">
          {error ? 'Could not load the directory.' : `${members?.length ?? 0} member${members?.length === 1 ? '' : 's'}`}
        </p>
        <div className="flex gap-1 rounded border border-paper-edge p-0.5">
          {[['', 'List'], ['card', 'Cards']].map(([v, label]) => (
            <Link
              key={label}
              href={{ pathname: '/directory', query: { ...sp, view: v || undefined } }}
              className={`rounded px-2.5 py-1 text-xs ${(sp.view ?? '') === v ? 'bg-ink-900 text-white' : 'text-ink-600 hover:bg-paper-sunk'}`}
            >
              {label}
            </Link>
          ))}
        </div>
      </div>

      {!members?.length ? (
        <Empty>No members match these filters. Try widening your search.</Empty>
      ) : cards ? (
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {members.map((m) => (
            <Link key={m.id} href={`/directory/${m.id}`}>
              <Card className="flex h-full gap-3 p-4 transition-colors hover:border-ink-200">
                <Avatar name={m.full_name} url={m.photo_url} />
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-ink-900">{m.full_name}</p>
                  <p className="text-xs text-ink-400">{m.enrolment_no}</p>
                  <p className="mt-1 text-xs text-ink-600">{DESIGNATION[m.designation]}</p>
                  <div className="mt-2 flex flex-wrap gap-1">
                    {(m.practice_areas as string[]).slice(0, 2).map((a) => (
                      <Badge key={a}>{a}</Badge>
                    ))}
                  </div>
                </div>
              </Card>
            </Link>
          ))}
        </div>
      ) : (
        <Card className="overflow-x-auto">
          <table className="w-full min-w-[46rem] text-sm">
            <thead>
              <tr className="border-b border-paper-edge text-left text-xs tracking-wide text-ink-400 uppercase">
                <th className="px-4 py-2.5 font-medium">Member</th>
                <th className="px-4 py-2.5 font-medium">Enrolment</th>
                <th className="px-4 py-2.5 font-medium">Designation</th>
                <th className="px-4 py-2.5 font-medium">Practice areas</th>
                <th className="px-4 py-2.5 font-medium">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-paper-sunk">
              {members.map((m) => (
                <tr key={m.id} className="hover:bg-paper">
                  <td className="px-4 py-2.5">
                    <Link href={`/directory/${m.id}`} className="flex items-center gap-2.5 font-medium text-ink-900 hover:text-rule">
                      <Avatar name={m.full_name} url={m.photo_url} size={8} />
                      {m.full_name}
                    </Link>
                  </td>
                  <td className="px-4 py-2.5 text-ink-600">
                    {m.enrolment_no}
                    {m.enrolment_date && <span className="block text-xs text-ink-400">{day(m.enrolment_date)}</span>}
                  </td>
                  <td className="px-4 py-2.5 text-ink-600">{DESIGNATION[m.designation]}</td>
                  <td className="px-4 py-2.5">
                    <div className="flex flex-wrap gap-1">
                      {(m.practice_areas as string[]).slice(0, 3).map((a) => (
                        <Badge key={a}>{a}</Badge>
                      ))}
                    </div>
                  </td>
                  <td className="px-4 py-2.5">
                    <Badge tone={['active', 'life'].includes(m.membership_status) ? 'green' : 'amber'}>
                      {m.membership_status}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}
    </>
  )
}

export function Avatar({ name, url, size = 11 }: { name: string; url?: string | null; size?: number }) {
  const initials = name.split(' ').filter(Boolean).slice(0, 2).map((w) => w[0]).join('')
  return url ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={url} alt="" className="shrink-0 rounded-full object-cover" style={{ width: `${size * 4}px`, height: `${size * 4}px` }} />
  ) : (
    <span
      aria-hidden
      className="flex shrink-0 items-center justify-center rounded-full bg-ink-100 font-display text-ink-600"
      style={{ width: `${size * 4}px`, height: `${size * 4}px`, fontSize: `${size * 1.4}px` }}
    >
      {initials}
    </span>
  )
}
