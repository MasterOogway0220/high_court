# GHCBA Member Dashboard

Member dashboard for the Guwahati High Court Bar Association. Next.js (frontend and
backend) on Supabase. Built from [`docs/GHCBA-Dashboard-PRD.md`](docs/GHCBA-Dashboard-PRD.md).

## Stack

| | |
|---|---|
| Framework | Next.js 16 (App Router) · React 19 · TypeScript |
| Styling | Tailwind CSS 4 |
| Data / auth / storage | Supabase (Postgres, `ap-south-1` Mumbai) |
| Hosting | Vercel |

The PRD specified .NET 8 + SQL Server + IIS. That was replaced with Next.js + Supabase —
see [Deviations](#deviations-from-the-prd).

## Setup

1. **Fill in `.env.local`.** Supabase → Project Settings → API Keys, and → Database for
   the password:

   ```
   NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon / public key>
   SUPABASE_SERVICE_ROLE_KEY=<service_role key>

   DATABASE_URL="postgresql://postgres.<ref>:<password>@<pooler-host>:6543/postgres?pgbouncer=true"
   DIRECT_URL="postgresql://postgres.<ref>:<password>@<pooler-host>:5432/postgres"
   ```

   Use the **pooler** host, not `db.<ref>.supabase.co` — the direct host is IPv6-only and
   unreachable from an IPv4-only network. Copy the exact string from Supabase → Connect →
   ORMs → Prisma; the pooler region is not always the project's region.

2. **Check the connection.** This tells you precisely what is wrong if it fails:

   ```bash
   npm run db:ping
   ```

3. **Apply the schema.**

   ```bash
   npm run db:apply
   ```

   Runs `supabase/migrations/*.sql` in order through the session pooler, then introspects
   the result with `prisma db pull` and regenerates the client:

   ```
   001_schema.sql     tables, enums, search indexes, audit triggers
   002_rls.sql        row-level security — the permission model
   003_functions.sql  login resolution, RSVP/waitlist, global search
   004_seed.sql       demo members, notices, events, documents
   005_check.sql      asserts the visibility rules actually hold
   ```

   `005` raises an exception if a general member can see restricted content. A clean run
   means the permission model is intact.

   You can equally paste these files into the Supabase SQL Editor in order — same result,
   no connection string needed.

4. **Run it.**

   ```bash
   npm install
   npm run dev
   ```

## Deploying to Vercel

`.env.local` is gitignored, so Vercel has none of it. Set these in **Project Settings →
Environment Variables** before deploying, or the build fails naming the missing variable:

| Variable | Needed for |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | everything |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | everything |
| `SUPABASE_SERVICE_ROLE_KEY` | the `.ics` calendar feed only |
| `DEMO_AUTO_LOGIN` | opening the dashboard without a sign-in step |
| `DEMO_AUTO_LOGIN_PASSWORD` | as above |

`DATABASE_URL` and `DIRECT_URL` are **not** needed at runtime — Prisma is only used
locally for schema work. Leave them out of Vercel.

A Vercel `404: NOT_FOUND` at the project domain means no deployment is serving that
route — usually a failed build, a Root Directory pointing at a folder that does not
exist, or a project created against an empty repository. Check the Deployments tab: if
the list is empty or the latest build is red, the 404 is a symptom, not the fault.

Do not set `DEMO_AUTO_LOGIN` on a production deployment. It signs every visitor in as
the named account.

### On Prisma and RLS

Prisma manages the schema; it does **not** serve member-facing queries.

Prisma connects as the `postgres` owner role, which bypasses row-level security — every
policy in `002_rls.sql` is inert on that connection, and a query through it returns
committee-only and office-bearer-only rows to anyone. So:

- **`supabase-js`** — anything a member sees. RLS and `auth.uid()` apply, which is what
  enforces PRD 2.1. This is the default.
- **Prisma** — schema management, introspection, and trusted server-side jobs that
  legitimately need to see everything (reporting, bulk import, scheduled work).

The SQL files stay the source of truth rather than `prisma migrate`, because RLS policies,
`SECURITY DEFINER` functions, triggers and generated `tsvector` columns have no
representation in the Prisma schema language. Prisma introspects what the SQL built.

### Demo accounts

Password for every seeded account: `demo1234`. Sign in with an enrolment number.

| Enrolment | Member | Sees |
|---|---|---|
| `GHCBA/OFFICE` | Association Secretariat | Everything — admin, audit log |
| `GHC/1995/108` | Pranab Kumar Das, Secretary | Office-bearer content, publishing |
| `GHC/2005/511` | Kaustubh Medhi | Committee-only content (Library Committee) |
| `GHC/2010/733` | Rupam Bordoloi | General member — restricted items are invisible |

Signing in as the last two side by side is the quickest way to see the permission model
working.

## How it is put together

**Permissions live in Postgres, not in application code.** Every content table carries a
`visibility` column (`all_members` / `committee_only` / `office_bearers_only`) and an RLS
policy that calls `sees(visibility)`. No page filters by role. A restricted document is not
hidden from the query — it is not returned by it.

Two consequences worth knowing:

- Committee standing is *derived* from current-term membership rather than stored as a
  flag, so removing someone from a committee revokes their access on the next query, with
  no cleanup step (PRD 3.8).
- The audit log is written by a trigger and has no `INSERT`/`UPDATE`/`DELETE` policy, so
  the application cannot alter it. That is what makes it immutable (PRD 4.4).

**Other decisions.** RSVP capacity is settled in a database function under an advisory
lock, so two members claiming the last seat cannot both win. Search is Postgres full-text
plus trigram — no external search service. Login accepts an enrolment number or a mobile
number, resolved to an email by one `SECURITY DEFINER` function rather than a parallel
credential store.

**Next.js 16 note.** `middleware.ts` is now `proxy.ts` — see `src/proxy.ts`. Most Supabase
SSR guides still show the old filename, which silently never runs.

## Deviations from the PRD

| PRD | Built | Why |
|---|---|---|
| .NET 8 + SQL Server + IIS | Next.js + Supabase + Vercel | Client decision |
| Appwrite (considered) | Supabase | Appwrite Cloud has no India region; §4.4 requires Indian data residency. Supabase offers `ap-south-1` Mumbai |
| OTP activation and reset via SMS | Password login only | No SMS gateway chosen yet — PRD open question 3 |

**Not yet built:** file upload and in-browser preview (documents and newsletter issues are
seeded as metadata; uploads must go browser→Supabase Storage directly, since Vercel caps
request bodies at ~4.5 MB against the PRD's 25 MB), scheduled publishing and reminder jobs
(`pg_cron`), email notifications, admin content CRUD, CSV member import, and PDF export.

## Layout

```
src/app/(auth)/login      sign in
src/app/(app)/            dashboard · directory · announcements · calendar · events
                          documents · newsletter · committee · contact
                          notifications · settings · admin
src/app/api/ics/[token]   tokenised, revocable calendar feed
src/proxy.ts              session refresh + route gate
src/lib/supabase/         server and browser clients
supabase/migrations/      schema, RLS, functions, seed, checks
```
