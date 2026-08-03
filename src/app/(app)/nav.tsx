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

// Grouped the way a file is indexed: what is happening now, what is on record,
// and who the Association is. The grouping carries meaning, so it earns its rules.
const GROUPS: { label: string; items: { href: string; label: string; icon: typeof Users }[] }[] = [
  {
    label: 'Current',
    items: [
      { href: '/', label: 'Dashboard', icon: LayoutDashboard },
      { href: '/announcements', label: 'Announcements', icon: Megaphone },
      { href: '/calendar', label: 'Calendar', icon: CalendarDays },
      { href: '/events', label: 'Events', icon: CalendarCheck },
    ],
  },
  {
    label: 'Records',
    items: [
      { href: '/directory', label: 'Directory', icon: Users },
      { href: '/documents', label: 'Documents', icon: FolderOpen },
      { href: '/newsletter', label: 'Newsletter', icon: BookOpen },
    ],
  },
  {
    label: 'Association',
    items: [
      { href: '/committee', label: 'Bar Committee', icon: Landmark },
      { href: '/contact', label: 'Contact', icon: Mail },
    ],
  },
]

const MOBILE = [
  { href: '/', label: 'Home', icon: LayoutDashboard },
  { href: '/announcements', label: 'Notices', icon: Megaphone },
  { href: '/directory', label: 'Directory', icon: Users },
  { href: '/events', label: 'Events', icon: CalendarCheck },
  { href: '/documents', label: 'Files', icon: FolderOpen },
]

export function Nav({ canPublish, isStaff }: { canPublish: boolean; isStaff: boolean }) {
  const path = usePathname()
  const active = (href: string) => (href === '/' ? path === '/' : path.startsWith(href))

  const item = (href: string, label: string, Icon: typeof Users) => (
    <li key={href}>
      <Link
        href={href}
        aria-current={active(href) ? 'page' : undefined}
        className={cn(
          'group relative flex items-center gap-2.5 py-1.5 pl-3 text-[13.5px] transition-colors',
          active(href) ? 'font-medium text-ink-900' : 'text-ink-500 hover:text-ink-900'
        )}
      >
        {/* the current entry is marked in the margin, as a file is */}
        <span
          className={cn(
            'absolute top-1/2 left-0 h-4 w-[2px] -translate-y-1/2 transition-colors',
            active(href) ? 'bg-rule' : 'bg-transparent group-hover:bg-ink-200'
          )}
        />
        <Icon size={15} className={active(href) ? 'text-rule' : 'text-ink-300'} />
        {label}
      </Link>
    </li>
  )

  return (
    <>
      <nav aria-label="Sections" className="hidden w-48 shrink-0 lg:block">
        <div className="sticky top-22 space-y-6">
          {GROUPS.map((g) => (
            <div key={g.label}>
              <p className="eyebrow ruled mb-2 pb-1.5">{g.label}</p>
              <ul>{g.items.map((i) => item(i.href, i.label, i.icon))}</ul>
            </div>
          ))}

          {(canPublish || isStaff) && (
            <div>
              <p className="eyebrow ruled mb-2 pb-1.5">Office</p>
              <ul>{item('/admin', 'Administration', ShieldCheck)}</ul>
            </div>
          )}
        </div>
      </nav>

      <nav
        aria-label="Sections"
        className="fixed inset-x-0 bottom-0 z-40 border-t border-paper-edge bg-paper-raised/95 backdrop-blur lg:hidden"
      >
        <ul className="flex">
          {MOBILE.map(({ href, label, icon: Icon }) => (
            <li key={href} className="flex-1">
              <Link
                href={href}
                aria-current={active(href) ? 'page' : undefined}
                className={cn(
                  'flex flex-col items-center gap-1 py-2.5 font-mono text-[9.5px] tracking-wide uppercase',
                  active(href) ? 'text-rule' : 'text-ink-400'
                )}
              >
                <Icon size={17} />
                {label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </>
  )
}
