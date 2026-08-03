'use client'

import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'
import { Search as SearchIcon } from 'lucide-react'
import { supabase } from '@/lib/supabase/client'

type Hit = { module: string; id: string; title: string; snippet: string | null; link: string }

const LABEL: Record<string, string> = {
  directory: 'Directory',
  announcements: 'Announcements',
  documents: 'Documents',
  events: 'Events',
  newsletter: 'Newsletter',
}

export function GlobalSearch() {
  const [q, setQ] = useState('')
  const [hits, setHits] = useState<Hit[]>([])
  const [open, setOpen] = useState(false)
  const box = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (q.trim().length < 2) return setHits([])
    const t = setTimeout(async () => {
      const { data } = await supabase.rpc('global_search', { q: q.trim(), per_module: 4 })
      setHits((data as Hit[]) ?? [])
    }, 200)
    return () => clearTimeout(t)
  }, [q])

  useEffect(() => {
    const away = (e: MouseEvent) => {
      if (box.current && !box.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', away)
    return () => document.removeEventListener('mousedown', away)
  }, [])

  const groups = Object.entries(
    hits.reduce<Record<string, Hit[]>>((acc, h) => {
      ;(acc[h.module] ??= []).push(h)
      return acc
    }, {})
  )

  return (
    <div ref={box} className="relative">
      <SearchIcon size={15} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-white/40" />
      <input
        value={q}
        onChange={(e) => {
          setQ(e.target.value)
          setOpen(true)
        }}
        onFocus={() => setOpen(true)}
        onKeyDown={(e) => e.key === 'Escape' && setOpen(false)}
        placeholder="Search members, notices, documents…"
        aria-label="Search the dashboard"
        className="h-9 w-full rounded border border-white/15 bg-white/10 pr-3 pl-9 text-sm text-white placeholder:text-white/40 focus:border-white/40 focus:bg-white/15 focus:outline-none"
      />

      {open && q.trim().length >= 2 && (
        <div className="absolute top-11 right-0 left-0 max-h-[70vh] overflow-y-auto rounded-md border border-sand-200 bg-white py-1.5 shadow-xl">
          {groups.length === 0 ? (
            <p className="px-4 py-3 text-sm text-ink-400">No results for “{q}”.</p>
          ) : (
            groups.map(([mod, list]) => (
              <div key={mod} className="py-1">
                <div className="flex items-center justify-between px-3 pb-1">
                  <span className="text-[10px] font-semibold tracking-wider text-ink-400 uppercase">
                    {LABEL[mod] ?? mod}
                  </span>
                  <Link
                    href={`/${mod === 'directory' ? 'directory' : mod}`}
                    onClick={() => setOpen(false)}
                    className="text-[11px] text-maroon-700 hover:underline"
                  >
                    See all
                  </Link>
                </div>
                {list.map((h) => (
                  <Link
                    key={`${h.module}-${h.id}`}
                    href={h.link}
                    onClick={() => setOpen(false)}
                    className="block px-3 py-2 hover:bg-sand-100"
                  >
                    <div className="truncate text-sm text-ink-900">{h.title}</div>
                    {h.snippet && <div className="truncate text-xs text-ink-400">{h.snippet}</div>}
                  </Link>
                ))}
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}
