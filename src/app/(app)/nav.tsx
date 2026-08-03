'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/ui'
import {
  LayoutDashboard,
  Users,
  Megaphone,
  CalendarDays,
  CalendarCheck,
  FolderOpen,
  BookOpen,
  Landmark,
  Mail,
  ShieldCheck,
} from 'lucide-react'

const MAIN = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/directory', label: 'Directory', icon: Users },
  { href: '/announcements', label: 'Announcements', icon: Megaphone },
  { href: '/calendar', label: 'Calendar', icon: CalendarDays },
  { href: '/events', label: 'Events', icon: CalendarCheck },
  { href: '/documents', label: 'Documents', icon: FolderOpen },
  { href: '/newsletter', label: 'Newsletter', icon: BookOpen },
  { href: '/committee', label: 'Bar Committee', icon: Landmark },
  { href: '/contact', label: 'Contact', icon: Mail },
]

export function Nav({ canPublish, isStaff }: { canPublish: boolean; isStaff: boolean }) {
  const path = usePathname()
  const active = (href: string) => (href === '/' ? path === '/' : path.startsWith(href))

  return (
    <>
      {/* desktop rail */}
      <nav aria-label="Sections" className="hidden w-52 shrink-0 lg:block">
        <ul className="sticky top-20 space-y-0.5">
          {MAIN.map(({ href, label, icon: Icon }) => (
            <li key={href}>
              <Link
                href={href}
                aria-current={active(href) ? 'page' : undefined}
                className={cn(
                  'flex items-center gap-2.5 rounded px-3 py-2 text-sm transition-colors',
                  active(href)
                    ? 'bg-white font-medium text-ink-900 shadow-[0_1px_2px_rgba(22,36,63,0.05)]'
                    : 'text-ink-600 hover:bg-sand-100 hover:text-ink-900'
                )}
              >
                <Icon size={16} className={active(href) ? 'text-maroon-700' : 'text-ink-400'} />
                {label}
              </Link>
            </li>
          ))}

          {(canPublish || isStaff) && (
            <li className="pt-4">
              <Link
                href="/admin"
                aria-current={active('/admin') ? 'page' : undefined}
                className={cn(
                  'flex items-center gap-2.5 rounded px-3 py-2 text-sm transition-colors',
                  active('/admin')
                    ? 'bg-white font-medium text-ink-900 shadow-[0_1px_2px_rgba(22,36,63,0.05)]'
                    : 'text-ink-600 hover:bg-sand-100 hover:text-ink-900'
                )}
              >
                <ShieldCheck size={16} className={active('/admin') ? 'text-maroon-700' : 'text-ink-400'} />
                Administration
              </Link>
            </li>
          )}
        </ul>
      </nav>

      {/* mobile bar */}
      <nav
        aria-label="Sections"
        className="fixed inset-x-0 bottom-0 z-40 border-t border-sand-200 bg-white/95 backdrop-blur lg:hidden"
      >
        <ul className="flex overflow-x-auto">
          {MAIN.map(({ href, label, icon: Icon }) => (
            <li key={href} className="flex-1">
              <Link
                href={href}
                aria-current={active(href) ? 'page' : undefined}
                className={cn(
                  'flex min-w-[4.5rem] flex-col items-center gap-1 px-2 py-2.5 text-[10px]',
                  active(href) ? 'text-maroon-700' : 'text-ink-400'
                )}
              >
                <Icon size={18} />
                {label.split(' ')[0]}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </>
  )
}
