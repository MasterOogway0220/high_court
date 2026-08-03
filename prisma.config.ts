import { config as loadEnv } from 'dotenv'
import { defineConfig } from 'prisma/config'

// The app keeps its secrets in .env.local (gitignored). Load that rather than a
// second .env file, so there is one place to put the connection string.
loadEnv({ path: '.env.local' })

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    // Session pooler (port 5432, IPv4). Introspection needs a session connection,
    // not the transaction pooler. The direct db.<ref>.supabase.co host is IPv6-only
    // and unreachable from any network without an IPv6 route.
    url: process.env.DIRECT_URL ?? process.env.DATABASE_URL,
  },
})
