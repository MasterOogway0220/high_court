// Verifies DATABASE_URL / DIRECT_URL actually reach the database, and says exactly
// what is wrong when they do not. Run: npm run db:ping
//
// Deliberately does not import the generated Prisma client — that client does not
// exist until a connection has succeeded, so depending on it here would make this
// diagnostic unusable at the exact moment it is needed.
import { config } from 'dotenv'
import postgres from 'postgres'

config({ path: '.env.local' })

const url = process.env.DIRECT_URL || process.env.DATABASE_URL

if (!url) {
  console.error('✗ Neither DIRECT_URL nor DATABASE_URL is set in .env.local')
  process.exit(1)
}
if (/PASSWORD|\[YOUR-PASSWORD\]/.test(url)) {
  console.error('✗ The connection string still contains the placeholder password.')
  console.error('  Supabase → Project Settings → Database → Database password')
  process.exit(1)
}

const host = url.match(/@([^:/]+)/)?.[1] ?? '?'
console.log(`→ ${host}`)

const sql = postgres(url, { ssl: 'require', max: 1, prepare: false, connect_timeout: 15 })

try {
  const [row] = await sql`
    select current_database() as db,
           current_user      as usr,
           (select count(*)::int from information_schema.tables
             where table_schema = 'public') as tables`
  console.log(`✓ connected — database=${row.db} user=${row.usr}`)
  console.log(`  ${row.tables} tables in the public schema`)
  await sql.end({ timeout: 2 })
  process.exit(0)
} catch (e) {
  const m = e.message ?? String(e)
  if (/password authentication failed/i.test(m)) {
    console.error('✗ Wrong password. Host and project are correct; the password is not.')
    console.error('  Reset it: Supabase → Project Settings → Database → Reset database password')
  } else if (/Tenant or user not found/i.test(m)) {
    console.error('✗ Wrong pooler region for this project.')
    console.error('  Copy the exact string from Supabase → Connect → ORMs → Prisma')
  } else if (/ENOTFOUND|EAI_AGAIN/i.test(m)) {
    console.error('✗ Host does not resolve. If it is db.<ref>.supabase.co, that host is')
    console.error('  IPv6-only — use the pooler host instead.')
  } else if (/ETIMEDOUT|ECONNREFUSED/i.test(m)) {
    console.error('✗ Name resolves but nothing answers — firewall, or an IPv6-only host.')
  } else {
    console.error(`✗ ${m.split('\n')[0]}`)
  }
  await sql.end({ timeout: 2 }).catch(() => {})
  process.exit(1)
}
