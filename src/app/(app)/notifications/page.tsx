import Link from 'next/link'
import { revalidatePath } from 'next/cache'
import { db, me } from '@/lib/supabase/server'
import { Badge, Button, Card, Empty, Heading } from '@/lib/ui'
import { ago } from '@/lib/format'

export const dynamic = 'force-dynamic'
export const metadata = { title: 'Notifications' }

async function markAllRead() {
  'use server'
  const member = await me()
  if (!member) return
  const supabase = await db()
  await supabase
    .from('notifications')
    .update({ read_at: new Date().toISOString() })
    .eq('member_id', member.id)
    .is('read_at', null)
  revalidatePath('/notifications')
}

export default async function NotificationsPage() {
  const supabase = await db()
  const { data } = await supabase
    .from('notifications')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(50)

  const unread = (data ?? []).filter((n) => !n.read_at).length

  return (
    <div className="mx-auto max-w-3xl">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <Heading sub="Notices, event reminders and updates on your enquiries.">Notifications</Heading>
        {unread > 0 && (
          <form action={markAllRead}>
            <Button variant="outline" size="sm">
              Mark all as read
            </Button>
          </form>
        )}
      </div>

      {!data?.length ? (
        <Empty>You have no notifications.</Empty>
      ) : (
        <ul className="space-y-2">
          {data.map((n) => (
            <li key={n.id}>
              <Card className={`p-4 ${n.read_at ? '' : 'border-l-2 border-l-brand-600'}`}>
                <div className="flex items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="mb-1 flex items-center gap-2">
                      <Badge tone="info">{n.kind}</Badge>
                      {!n.read_at && <span className="h-1.5 w-1.5 rounded-full bg-brand-600" aria-label="Unread" />}
                    </div>
                    {n.link ? (
                      <Link href={n.link} className="text-sm font-medium text-ink-900 hover:text-brand-600">
                        {n.title}
                      </Link>
                    ) : (
                      <p className="text-sm font-medium text-ink-900">{n.title}</p>
                    )}
                    {n.body && <p className="mt-0.5 text-sm text-ink-500">{n.body}</p>}
                  </div>
                  <span className="shrink-0 text-xs text-ink-400">{ago(n.created_at)}</span>
                </div>
              </Card>
            </li>
          ))}
        </ul>
      )}

      <p className="mt-6 text-center text-sm text-ink-400">
        Manage which notifications reach you by email in{' '}
        <Link href="/settings" className="text-brand-600 hover:underline">
          Settings
        </Link>
        .
      </p>
    </div>
  )
}
