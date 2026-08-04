// Creates the single demo account, end to end, through the session pooler.
//
// The Supabase Admin API is unavailable here — SUPABASE_SERVICE_ROLE_KEY in
// .env.local is still the PASTE_… placeholder — so the auth row is written
// directly. GoTrue authenticates against auth.users.encrypted_password, and
// pgcrypto's bcrypt is exactly what it expects to find there.
//
// Idempotent: re-running updates the password and roles rather than failing.
import { config } from 'dotenv'
import postgres from 'postgres'

config({ path: '.env.local' })

const EMAIL = 'demo@gmail.com'
const PASSWORD = 'Pass@123'
const ENROLMENT = 'GHC/DEMO/001'
const NAME = 'Demo Member'

const sql = postgres(process.env.DIRECT_URL, {
  ssl: 'require',
  max: 1,
  prepare: false,
  connect_timeout: 20,
})

try {
  await sql`create extension if not exists pgcrypto with schema extensions`

  // One auth user. gen_salt('bf') is bcrypt, which is what GoTrue verifies with.
  //
  // The four token columns are set to '' rather than left NULL on purpose.
  // They are nullable in the table but GoTrue scans them into non-nullable Go
  // strings, so a NULL makes every sign-in fail with "Database error querying
  // schema" — a 500 that says nothing about the actual cause.
  const [user] = await sql`
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous
    ) values (
      '00000000-0000-0000-0000-000000000000',
      gen_random_uuid(), 'authenticated', 'authenticated',
      ${EMAIL}, extensions.crypt(${PASSWORD}, extensions.gen_salt('bf')),
      now(), now(), now(),
      '', '', '', '',
      '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, false, false
    )
    on conflict (email) where (is_sso_user = false) do update
      set encrypted_password       = extensions.crypt(${PASSWORD}, extensions.gen_salt('bf')),
          email_confirmed_at       = now(),
          updated_at               = now(),
          confirmation_token       = '',
          recovery_token           = '',
          email_change_token_new   = '',
          email_change             = ''
    returning id
  `
  const id = user.id
  console.log('auth user :', id)

  // GoTrue expects an identity row for the email provider alongside the user.
  await sql`
    insert into auth.identities (
      id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), ${id}, ${id},
      ${sql.json({ sub: id, email: EMAIL, email_verified: true, phone_verified: false })},
      'email', now(), now(), now()
    )
    on conflict (provider_id, provider) do update set updated_at = now()
  `

  // The directory record. members.id is the auth user id — that FK is the join.
  await sql`
    insert into members (
      id, enrolment_no, full_name, email, designation, membership_status,
      enrolment_date, chamber_address, mobile, practice_areas, bio
    ) values (
      ${id}, ${ENROLMENT}, ${NAME}, ${EMAIL}, 'advocate', 'active',
      '2015-06-01', 'Chamber 12, High Court Bar Building, Guwahati',
      '9000000000',
      ${sql.array(['Constitutional', 'Civil', 'Criminal'])},
      'Demonstration account for the GHCBA member app.'
    )
    on conflict (id) do update
      set enrolment_no = excluded.enrolment_no,
          full_name    = excluded.full_name,
          email        = excluded.email
  `

  // One role, and the highest one: super_admin satisfies is_staff(), can_publish()
  // and is_committee(), so sees() returns true for all three visibility levels and
  // every page is reachable. No role variations — there is a single demo account.
  await sql`
    insert into member_roles (member_id, role)
    values (${id}, 'super_admin')
    on conflict (member_id, role) do nothing
  `

  // Notifications are per-member, so a fresh account lands on an empty bell.
  // Correct behaviour, poor demo — give it something to show.
  await sql`delete from notifications where member_id = ${id}`
  await sql`
    insert into notifications (member_id, kind, title, body, link, created_at, read_at)
    select ${id}, kind, title, body, link,
           now() - (offset_hours || ' hours')::interval,
           case when seen then now() else null end
    from (values
      ('announcement', 'New circular published',
       'Vacation bench roster for the coming session is now on the notice board.',
       '/announcements', 2, false),
      ('event', 'RSVP closing soon',
       'Confirm your attendance for the Continuing Legal Education seminar.',
       '/events', 20, false),
      ('newsletter', 'The Gauhati Bar Review',
       'The latest issue of the Association journal has been published.',
       '/newsletter', 76, true)
    ) as t(kind, title, body, link, offset_hours, seen)
  `

  const roles = await sql`select role from member_roles where member_id = ${id}`
  const [check] = await sql`select email_for_login(${EMAIL}) as email`

  console.log('member    :', ENROLMENT, '·', NAME)
  console.log('roles     :', roles.map((r) => r.role).join(', '))
  console.log('login res :', check.email)
} finally {
  await sql.end()
}
