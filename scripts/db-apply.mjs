// Applies the SQL migrations in order through the session pooler, then introspects
// the result into prisma/schema.prisma. Run: npm run db:apply
//
// The SQL files stay the source of truth rather than `prisma migrate`, because RLS
// policies, SECURITY DEFINER functions, triggers and generated tsvector columns have
// no representation in the Prisma schema language. Prisma introspects what the SQL
// built; it does not define it.
import { config } from 'dotenv'
import { readFileSync, readdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import postgres from 'postgres'

config({ path: '.env.local' })

const url = process.env.DIRECT_URL
if (!url || url.includes('PASSWORD')) {
  console.error('✗ DIRECT_URL is missing or still has the placeholder password. Run: npm run db:ping')
  process.exit(1)
}

const dir = 'supabase/migrations'
const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()

// Session mode (port 5432), one connection, no prepared statements — the seed and
// policy files run multi-statement DDL that transaction pooling would break up.
const sql = postgres(url, { ssl: 'require', max: 1, prepare: false, connect_timeout: 20, idle_timeout: 120 })

let failed = false
for (const f of files) {
  const body = readFileSync(`${dir}/${f}`, 'utf8')
  process.stdout.write(`  ${f} … `)
  try {
    await sql.unsafe(body)
    console.log('ok')
  } catch (e) {
    console.log('FAILED')
    console.error(`\n${e.message}\n`)
    if (e.position) console.error(`  at character ${e.position}`)
    failed = true
    break
  }
}

await sql.end({ timeout: 5 }).catch(() => {})

if (failed) process.exit(1)

console.log('\nIntrospecting into prisma/schema.prisma …')
execFileSync('npx', ['prisma', 'db', 'pull'], { stdio: 'inherit', shell: true })
execFileSync('npx', ['prisma', 'generate'], { stdio: 'inherit', shell: true })
console.log('\nDone.')
