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
  const input = useRef<HTMLInputElement>(null)

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
    // The keycap in the field has to do what it says.
    const key = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        input.current?.focus()
      }
    }
    document.addEventListener('mousedown', away)
    document.addEventListener('keydown', key)
    return () => {
      document.removeEventListener('mousedown', away)
      document.removeEventListener('keydown', key)
    }
  }, [])

  const groups = Object.entries(
    hits.reduce<Record<string, Hit[]>>((acc, h) => {
      ;(acc[h.module] ??= []).push(h)
      return acc
    }, {})
  )

  return (
    <div ref={box} className="relative">
      <SearchIcon
        size={16}
        className="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-ink-400"
      />
      <input
        ref={input}
        value={q}
        onChange={(e) => {
          setQ(e.target.value)
          setOpen(true)
        }}
        onFocus={() => setOpen(true)}
        onKeyDown={(e) => e.key === 'Escape' && setOpen(false)}
        placeholder="Search members, notices, documents"
        aria-label="Search the dashboard"
        className="h-11 w-full rounded-lg bg-paper-sunk pr-16 pl-11 text-[13px] text-ink-900 placeholder:text-ink-400 focus:bg-white focus:outline-2 focus:outline-brand-400"
      />
      <kbd className="pointer-events-none absolute top-1/2 right-2.5 hidden -translate-y-1/2 rounded-md bg-white px-2 py-1 text-[10.5px] font-semibold text-ink-400 sm:block">
        ⌘ K
      </kbd>

      {open && q.trim().length >= 2 && (
        <div className="absolute top-13 right-0 left-0 z-50 max-h-[70vh] overflow-y-auto rounded-2xl border border-paper-edge bg-white p-1.5 shadow-[0_12px_32px_rgba(16,27,20,0.12)]">
          {groups.length === 0 ? (
            <p className="px-3 py-3 text-[13px] text-ink-400">No results for “{q}”.</p>
          ) : (
            groups.map(([mod, list]) => (
              <div key={mod} className="py-1">
                <div className="flex items-center justify-between px-2.5 pb-1">
                  <span className="eyebrow">{LABEL[mod] ?? mod}</span>
                  <Link
                    href={`/${mod}`}
                    onClick={() => setOpen(false)}
                    className="text-[11px] font-semibold text-brand-600 hover:underline"
                  >
                    See all
                  </Link>
                </div>
                {list.map((h) => (
                  <Link
                    key={`${h.module}-${h.id}`}
                    href={h.link}
                    onClick={() => setOpen(false)}
                    className="block rounded-xl px-2.5 py-2 hover:bg-paper-sunk"
                  >
                    <div className="truncate text-[13px] font-medium text-ink-900">{h.title}</div>
                    {h.snippet && <div className="truncate text-[11.5px] text-ink-400">{h.snippet}</div>}
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
