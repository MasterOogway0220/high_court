'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/ui'
import { signOut } from '../(auth)/login/actions'
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
  Settings,
  LogOut,
  Scale,
} from 'lucide-react'

type Item = { href: string; label: string; icon: typeof Users }

const MENU: Item[] = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/announcements', label: 'Announcements', icon: Megaphone },
  { href: '/calendar', label: 'Calendar', icon: CalendarDays },
  { href: '/events', label: 'Events', icon: CalendarCheck },
  { href: '/directory', label: 'Directory', icon: Users },
  { href: '/documents', label: 'Documents', icon: FolderOpen },
  { href: '/newsletter', label: 'Newsletter', icon: BookOpen },
  { href: '/committee', label: 'Bar Committee', icon: Landmark },
]

const MOBILE: Item[] = [
  { href: '/', label: 'Home', icon: LayoutDashboard },
  { href: '/announcements', label: 'Notices', icon: Megaphone },
  { href: '/directory', label: 'Directory', icon: Users },
  { href: '/events', label: 'Events', icon: CalendarCheck },
  { href: '/documents', label: 'Files', icon: FolderOpen },
]

export function Nav({
  canPublish,
  isStaff,
  unread,
  demo,
}: {
  canPublish: boolean
  isStaff: boolean
  unread: number
  demo: boolean
}) {
  const path = usePathname()
  const active = (href: string) => (href === '/' ? path === '/' : path.startsWith(href))

  const item = ({ href, label, icon: Icon }: Item, count?: number) => {
    const on = active(href)
    return (
      <li key={href}>
        <Link
          href={href}
          aria-current={on ? 'page' : undefined}
          className={cn(
            'group relative flex h-9.5 items-center gap-3 rounded-lg px-2 text-[13.5px] transition-colors',
            on ? 'font-semibold text-ink-900' : 'text-ink-500 hover:bg-paper-sunk hover:text-ink-900'
          )}
        >
          {/* the current section is marked in the panel margin */}
          {on && (
            <span className="absolute top-1/2 -left-5 h-5 w-[3px] -translate-y-1/2 rounded-r-full bg-brand-400" />
          )}
          <Icon size={17} className={on ? 'text-ink-900' : 'text-ink-400'} />
          <span className="truncate">{label}</span>
          {!!count && (
            <span className="ml-auto rounded-md bg-brand-400 px-1.5 py-0.5 text-[10px] font-bold text-ink-900 tabular-nums">
              {count > 99 ? '99+' : count}
            </span>
          )}
        </Link>
      </li>
    )
  }

  return (
    <>
      <aside
        aria-label="Sections"
        className="sticky top-0 hidden h-dvh w-60 shrink-0 flex-col overflow-y-auto border-r border-paper-edge px-5 py-6 lg:flex"
      >
        <Link href="/" className="mb-8 flex items-center gap-2.5 px-2">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-brand-600 text-white">
            <Scale size={18} />
          </span>
          <span className="leading-none">
            <span className="block text-[17px] font-extrabold tracking-tight text-ink-900">GHCBA</span>
            <span className="mt-1 block text-[10px] font-medium text-ink-400">Bar Association</span>
          </span>
        </Link>

        <p className="eyebrow mb-2 px-2">Menu</p>
        <ul className="space-y-0.5">
          {MENU.map((i) => item(i, i.href === '/announcements' ? unread : undefined))}
        </ul>

        <p className="eyebrow mt-7 mb-2 px-2">General</p>
        <ul className="space-y-0.5">
          {(canPublish || isStaff) &&
            item({ href: '/admin', label: 'Administration', icon: ShieldCheck })}
          {item({ href: '/settings', label: 'Settings', icon: Settings })}
          {item({ href: '/contact', label: 'Help', icon: Mail })}
          {!demo && (
            <li>
              <form action={signOut}>
                <button className="flex h-9.5 w-full items-center gap-3 rounded-lg px-2 text-[13.5px] text-ink-500 transition-colors hover:bg-paper-sunk hover:text-ink-900">
                  <LogOut size={17} className="text-ink-400" />
                  Logout
                </button>
              </form>
            </li>
          )}
        </ul>
      </aside>

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
                  'flex flex-col items-center gap-1 py-2.5 text-[10px] font-semibold',
                  active(href) ? 'text-brand-600' : 'text-ink-400'
                )}
              >
                <Icon size={18} />
                {label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </>
  )
}
