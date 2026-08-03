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

1. **Run the migrations.** In the Supabase dashboard → SQL Editor, run in order:

   ```
   supabase/migrations/001_schema.sql     tables, enums, search indexes, audit triggers
   supabase/migrations/002_rls.sql        row-level security — the permission model
   supabase/migrations/003_functions.sql  login resolution, RSVP/waitlist, global search
   supabase/migrations/004_seed.sql       demo members, notices, events, documents
   supabase/migrations/005_check.sql      asserts the visibility rules actually hold
   ```

   `005` prints `RLS visibility checks passed.` and raises an exception if they do not.

2. **Add your keys** to `.env.local` (Supabase → Project Settings → API Keys):

   ```
   NEXT_PUBLIC_SUPABASE_URL=https://<ref>.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon / public key>
   SUPABASE_SERVICE_ROLE_KEY=<service_role key>
   ```

3. **Run it.**

   ```bash
   npm install
   npm run dev
   ```

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
