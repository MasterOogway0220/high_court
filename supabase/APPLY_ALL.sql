-- GHCBA — complete schema, security, functions, demo data and checks.
-- Paste this whole file into the Supabase SQL Editor and Run.
-- Safe to re-run: it truncates seeded data and recreates policies.
-- Expect a final notice: 'RLS visibility checks passed.'


-- ═══════════════════════════════════════════════════════════════
-- 001_schema.sql
-- ═══════════════════════════════════════════════════════════════

-- GHCBA Member Dashboard — schema
-- Run in Supabase SQL Editor. Idempotent-ish: drops and recreates the ghcba schema objects.

create extension if not exists pg_trgm;
create extension if not exists unaccent;

-- ─────────────────────────────────────────────────────────── enums

do $$ begin
  create type visibility as enum ('all_members', 'committee_only', 'office_bearers_only');
exception when duplicate_object then null; end $$;

do $$ begin
  create type app_role as enum ('member', 'committee', 'office_bearer', 'admin', 'super_admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type membership_status as enum ('active', 'life', 'suspended', 'retired', 'deceased');
exception when duplicate_object then null; end $$;

do $$ begin
  create type designation as enum ('senior_advocate', 'advocate', 'advocate_on_record');
exception when duplicate_object then null; end $$;

do $$ begin
  create type announcement_category as enum
    ('general', 'court_notice', 'condolence', 'election', 'welfare_scheme', 'meeting_notice', 'urgent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type priority as enum ('normal', 'important', 'urgent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type publish_status as enum ('draft', 'review', 'published');
exception when duplicate_object then null; end $$;

do $$ begin
  create type calendar_entry_type as enum
    ('court_holiday', 'association_meeting', 'gbm_egm', 'event', 'election', 'hearing_of_interest', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type event_type as enum
    ('seminar', 'cle_training', 'cultural', 'sports', 'felicitation', 'agm', 'farewell', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type rsvp_status as enum ('attending', 'not_attending', 'maybe');
exception when duplicate_object then null; end $$;

do $$ begin
  create type ticket_category as enum
    ('general', 'membership', 'welfare_scheme', 'grievance', 'technical_support', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type ticket_status as enum ('open', 'in_progress', 'resolved');
exception when duplicate_object then null; end $$;

do $$ begin
  create type committee_kind as enum ('office_bearers', 'executive', 'standing', 'sub');
exception when duplicate_object then null; end $$;

-- ─────────────────────────────────────────────────────────── members

create table if not exists members (
  id                uuid primary key references auth.users(id) on delete cascade,
  enrolment_no      text unique not null,
  full_name         text not null,
  photo_url         text,
  designation       designation not null default 'advocate',
  enrolment_date    date,
  chamber_address   text,
  chamber_phone     text,
  mobile            text,
  email             text,
  membership_status membership_status not null default 'active',
  practice_areas    text[] not null default '{}',
  bio               text check (char_length(bio) <= 500),
  hide_mobile       boolean not null default false,
  hide_email        boolean not null default false,
  last_seen_at      timestamptz,
  created_at        timestamptz not null default now()
);

-- search vector for directory: name + enrolment + practice areas + chamber
alter table members drop column if exists search_tsv;
alter table members add column search_tsv tsvector
  generated always as (
    to_tsvector('simple',
      coalesce(full_name, '') || ' ' ||
      coalesce(enrolment_no, '') || ' ' ||
      coalesce(array_to_string(practice_areas, ' '), '') || ' ' ||
      coalesce(chamber_address, ''))
  ) stored;

create index if not exists members_search_idx   on members using gin (search_tsv);
create index if not exists members_name_trgm    on members using gin (full_name gin_trgm_ops);
create index if not exists members_enrol_trgm   on members using gin (enrolment_no gin_trgm_ops);
create index if not exists members_status_idx   on members (membership_status);
create index if not exists members_practice_idx on members using gin (practice_areas);

create table if not exists member_roles (
  member_id uuid not null references members(id) on delete cascade,
  role      app_role not null,
  primary key (member_id, role)
);

-- moderation queue: name / enrolment_no / designation changes need approval (PRD 3.2)
create table if not exists member_profile_changes (
  id           bigserial primary key,
  member_id    uuid not null references members(id) on delete cascade,
  field        text not null,
  old_value    text,
  new_value    text,
  status       text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by  uuid references members(id),
  reviewed_at  timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists mpc_member_idx on member_profile_changes (member_id, status);

-- ─────────────────────────────────────────────────────────── announcements

create table if not exists announcements (
  id          bigserial primary key,
  title       text not null,
  body        text not null default '',
  category    announcement_category not null default 'general',
  priority    priority not null default 'normal',
  visibility  visibility not null default 'all_members',
  status      publish_status not null default 'draft',
  pinned      boolean not null default false,
  publish_at  timestamptz not null default now(),
  expires_at  timestamptz,
  author_id   uuid references members(id),
  created_at  timestamptz not null default now()
);

alter table announcements drop column if exists search_tsv;
alter table announcements add column search_tsv tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(body, '')), 'B')
  ) stored;

create index if not exists ann_search_idx on announcements using gin (search_tsv);
create index if not exists ann_feed_idx   on announcements (status, publish_at desc);

create table if not exists announcement_attachments (
  id              bigserial primary key,
  announcement_id bigint not null references announcements(id) on delete cascade,
  file_path       text not null,
  file_name       text not null,
  size_bytes      bigint,
  mime_type       text
);

create table if not exists announcement_reads (
  announcement_id bigint not null references announcements(id) on delete cascade,
  member_id       uuid   not null references members(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (announcement_id, member_id)
);

-- ─────────────────────────────────────────────────────────── events

create table if not exists events (
  id             bigserial primary key,
  title          text not null,
  description    text default '',
  banner_url     text,
  event_type     event_type not null default 'seminar',
  starts_at      timestamptz not null,
  ends_at        timestamptz,
  venue          text,
  organiser_id   uuid references members(id),
  capacity       int check (capacity is null or capacity > 0),
  rsvp_deadline  timestamptz,
  allow_guests   boolean not null default false,
  show_attendees boolean not null default false,
  visibility     visibility not null default 'all_members',
  outcome_note   text,
  created_at     timestamptz not null default now()
);

alter table events drop column if exists search_tsv;
alter table events add column search_tsv tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B')
  ) stored;

create index if not exists events_search_idx on events using gin (search_tsv);
create index if not exists events_date_idx   on events (starts_at desc);

create table if not exists event_rsvps (
  event_id    bigint not null references events(id) on delete cascade,
  member_id   uuid   not null references members(id) on delete cascade,
  status      rsvp_status not null,
  guests      int not null default 0 check (guests >= 0),
  waitlisted  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (event_id, member_id)
);
create index if not exists rsvp_event_idx on event_rsvps (event_id, status, waitlisted, created_at);

create table if not exists event_gallery (
  id         bigserial primary key,
  event_id   bigint not null references events(id) on delete cascade,
  file_path  text not null,
  caption    text,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────── calendar

create table if not exists calendar_entries (
  id          bigserial primary key,
  title       text not null,
  description text,
  entry_type  calendar_entry_type not null default 'other',
  starts_at   timestamptz not null,
  ends_at     timestamptz,
  all_day     boolean not null default false,
  event_id    bigint references events(id) on delete cascade,
  visibility  visibility not null default 'all_members',
  created_at  timestamptz not null default now()
);
create index if not exists cal_range_idx on calendar_entries (starts_at, ends_at);

-- per-member revocable .ics token (PRD 3.4 acceptance criteria)
create table if not exists ics_tokens (
  token      text primary key,
  member_id  uuid not null references members(id) on delete cascade,
  revoked    boolean not null default false,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────── documents

create table if not exists folders (
  id        bigserial primary key,
  name      text not null,
  parent_id bigint references folders(id) on delete cascade,
  sort      int not null default 0
);

create table if not exists documents (
  id             bigserial primary key,
  title          text not null,
  description    text default '',
  folder_id      bigint references folders(id) on delete set null,
  tags           text[] not null default '{}',
  visibility     visibility not null default 'all_members',
  download_count int not null default 0,
  uploader_id    uuid references members(id),
  deleted_at     timestamptz,
  created_at     timestamptz not null default now()
);

alter table documents drop column if exists search_tsv;
alter table documents add column search_tsv tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'C')
  ) stored;

create index if not exists doc_search_idx on documents using gin (search_tsv);
create index if not exists doc_folder_idx on documents (folder_id) where deleted_at is null;

create table if not exists document_versions (
  id          bigserial primary key,
  document_id bigint not null references documents(id) on delete cascade,
  version     int not null,
  file_path   text not null,
  file_name   text not null,
  size_bytes  bigint,
  mime_type   text,
  uploaded_by uuid references members(id),
  created_at  timestamptz not null default now(),
  unique (document_id, version)
);

-- ─────────────────────────────────────────────────────────── newsletter

create table if not exists newsletter_issues (
  id            bigserial primary key,
  issue_no      text not null,
  title         text not null,
  period        text,
  cover_url     text,
  editorial     text,
  pdf_path      text,
  status        publish_status not null default 'draft',
  published_at  timestamptz,
  document_id   bigint references documents(id) on delete set null,
  created_at    timestamptz not null default now()
);

create table if not exists newsletter_submissions (
  id         bigserial primary key,
  member_id  uuid references members(id) on delete set null,
  title      text not null,
  abstract   text,
  file_path  text,
  status     text not null default 'submitted',
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────── committees

create table if not exists committee_terms (
  id         bigserial primary key,
  label      text not null,
  start_year int  not null,
  end_year   int  not null,
  is_current boolean not null default false
);

create table if not exists committees (
  id          bigserial primary key,
  term_id     bigint not null references committee_terms(id) on delete cascade,
  name        text not null,
  kind        committee_kind not null default 'standing',
  mandate     text,
  convenor_id uuid references members(id),
  formed_on   date,
  sort        int not null default 0
);

create table if not exists committee_members (
  id           bigserial primary key,
  committee_id bigint not null references committees(id) on delete cascade,
  member_id    uuid   not null references members(id) on delete cascade,
  designation  text,
  sort         int not null default 0,
  unique (committee_id, member_id)
);

create table if not exists committee_documents (
  committee_id bigint not null references committees(id) on delete cascade,
  document_id  bigint not null references documents(id) on delete cascade,
  primary key (committee_id, document_id)
);

-- ─────────────────────────────────────────────────────────── contact / tickets

create table if not exists tickets (
  id          bigserial primary key,
  ref_no      text unique not null,
  member_id   uuid references members(id) on delete set null,
  category    ticket_category not null default 'general',
  subject     text not null,
  message     text not null,
  status      ticket_status not null default 'open',
  assigned_to uuid references members(id),
  file_path   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists tickets_member_idx on tickets (member_id, created_at desc);

create table if not exists ticket_messages (
  id         bigserial primary key,
  ticket_id  bigint not null references tickets(id) on delete cascade,
  author_id  uuid references members(id),
  body       text not null,
  internal   boolean not null default false,
  created_at timestamptz not null default now()
);

-- readable reference number: GHCBA-2026-000042
create sequence if not exists ticket_ref_seq;
create or replace function set_ticket_ref() returns trigger language plpgsql as $$
begin
  if new.ref_no is null or new.ref_no = '' then
    new.ref_no := 'GHCBA-' || to_char(now(), 'YYYY') || '-' ||
                  lpad(nextval('ticket_ref_seq')::text, 6, '0');
  end if;
  return new;
end $$;

drop trigger if exists tickets_ref on tickets;
create trigger tickets_ref before insert on tickets
  for each row execute function set_ticket_ref();

-- ─────────────────────────────────────────────────────────── notifications

create table if not exists notifications (
  id         bigserial primary key,
  member_id  uuid not null references members(id) on delete cascade,
  kind       text not null,
  title      text not null,
  body       text,
  link       text,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notif_member_idx on notifications (member_id, read_at, created_at desc);

create table if not exists notification_prefs (
  member_id     uuid not null references members(id) on delete cascade,
  category      text not null,
  email_enabled boolean not null default true,
  primary key (member_id, category)
);

-- ─────────────────────────────────────────────────────────── audit log

create table if not exists audit_log (
  id         bigserial primary key,
  actor_id   uuid,
  action     text not null,
  table_name text not null,
  row_id     text,
  data       jsonb,
  ip         inet,
  at         timestamptz not null default now()
);
create index if not exists audit_at_idx on audit_log (at desc);

-- generic audit trigger, attached to every content table below
create or replace function audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  rid text;
begin
  begin
    rid := coalesce((to_jsonb(new) ->> 'id'), (to_jsonb(old) ->> 'id'));
  exception when others then rid := null; end;

  insert into audit_log (actor_id, action, table_name, row_id, data)
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    rid,
    case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end
  );
  return case when tg_op = 'DELETE' then old else new end;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'members', 'member_roles', 'announcements', 'events', 'event_rsvps',
    'calendar_entries', 'documents', 'document_versions', 'folders',
    'newsletter_issues', 'committees', 'committee_members', 'tickets'
  ] loop
    execute format('drop trigger if exists audit_%1$s on %1$s', t);
    execute format(
      'create trigger audit_%1$s after insert or update or delete on %1$s
         for each row execute function audit_row()', t);
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 002_rls.sql
-- ═══════════════════════════════════════════════════════════════

-- GHCBA — row level security. This file IS the permission model (PRD 2.1).
-- Every read path goes through `sees(visibility)`; nothing is gated in app code.

-- ─────────────────────────────────────────────────────────── helpers
-- security definer so policies can read member_roles without recursing into its own RLS

create or replace function my_roles() returns app_role[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(role), '{}') from member_roles where member_id = auth.uid();
$$;

create or replace function is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from member_roles
    where member_id = auth.uid() and role in ('admin', 'super_admin')
  );
$$;

-- may publish content: office bearers and up (PRD 3.3 "only Office Bearers and Admin may publish")
create or replace function can_publish() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from member_roles
    where member_id = auth.uid() and role in ('office_bearer', 'admin', 'super_admin')
  );
$$;

-- committee standing is DERIVED from current-term membership, never stored as a flag.
-- That is what makes PRD 3.8 true by construction: remove someone from a committee and
-- their `committee_only` access is gone on the next query, with no cleanup step.
create or replace function is_committee() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from committee_members cm
    join committees c      on c.id = cm.committee_id
    join committee_terms t on t.id = c.term_id
    where cm.member_id = auth.uid() and t.is_current
  ) or can_publish();
$$;

create or replace function sees(v visibility) returns boolean
language sql stable security definer set search_path = public as $$
  select case v
    when 'all_members'         then auth.uid() is not null
    when 'committee_only'      then is_committee()
    when 'office_bearers_only' then can_publish()
  end;
$$;

-- an announcement is live if published, past its publish time
create or replace function is_live(s publish_status, publish_at timestamptz) returns boolean
language sql immutable as $$
  select s = 'published' and publish_at <= now();
$$;

-- ─────────────────────────────────────────────────────────── enable RLS everywhere

do $$
declare t text;
begin
  foreach t in array array[
    'members', 'member_roles', 'member_profile_changes',
    'announcements', 'announcement_attachments', 'announcement_reads',
    'events', 'event_rsvps', 'event_gallery',
    'calendar_entries', 'ics_tokens',
    'folders', 'documents', 'document_versions',
    'newsletter_issues', 'newsletter_submissions',
    'committee_terms', 'committees', 'committee_members', 'committee_documents',
    'tickets', 'ticket_messages',
    'notifications', 'notification_prefs', 'audit_log'
  ] loop
    execute format('alter table %I enable row level security', t);
    -- drop any prior policies so this file can be re-run
    execute format(
      'do $inner$ declare p record; begin
         for p in select policyname from pg_policies where tablename = %L loop
           execute format(''drop policy if exists %%I on %I'', p.policyname);
         end loop;
       end $inner$', t, t);
  end loop;
end $$;

-- ─────────────────────────────────────────────────────────── members & roles

create policy members_read on members for select
  using (auth.uid() is not null);

create policy members_self_update on members for update
  using (id = auth.uid()) with check (id = auth.uid());

create policy members_staff_write on members for all
  using (is_staff()) with check (is_staff());

create policy roles_read on member_roles for select
  using (auth.uid() is not null);

create policy roles_staff_write on member_roles for all
  using (is_staff()) with check (is_staff());

create policy mpc_own on member_profile_changes for select
  using (member_id = auth.uid() or is_staff());

create policy mpc_insert on member_profile_changes for insert
  with check (member_id = auth.uid());

create policy mpc_staff on member_profile_changes for update
  using (is_staff()) with check (is_staff());

-- ─────────────────────────────────────────────────────────── announcements
-- Expired announcements stay readable: PRD 3.3 wants them out of the feed but still
-- in the archive. The feed query filters on expires_at; RLS does not.

create policy ann_read on announcements for select
  using ((is_live(status, publish_at) and sees(visibility)) or can_publish());

create policy ann_write on announcements for all
  using (can_publish()) with check (can_publish());

create policy ann_att_read on announcement_attachments for select
  using (exists (select 1 from announcements a where a.id = announcement_id));

create policy ann_att_write on announcement_attachments for all
  using (can_publish()) with check (can_publish());

create policy reads_own on announcement_reads for select
  using (member_id = auth.uid() or is_staff());

create policy reads_insert on announcement_reads for insert
  with check (member_id = auth.uid());

-- ─────────────────────────────────────────────────────────── events

create policy events_read on events for select
  using (sees(visibility));

create policy events_write on events for all
  using (can_publish()) with check (can_publish());

-- attendee list: organiser and staff always; members only if the organiser opened it (PRD 3.5)
create policy rsvp_read on event_rsvps for select
  using (
    member_id = auth.uid()
    or can_publish()
    or exists (
      select 1 from events e
      where e.id = event_id and (e.show_attendees or e.organiser_id = auth.uid())
    )
  );

create policy rsvp_own_write on event_rsvps for all
  using (member_id = auth.uid()) with check (member_id = auth.uid());

create policy gallery_read on event_gallery for select
  using (exists (select 1 from events e where e.id = event_id));

create policy gallery_write on event_gallery for all
  using (can_publish()) with check (can_publish());

-- ─────────────────────────────────────────────────────────── calendar

create policy cal_read on calendar_entries for select
  using (sees(visibility));

create policy cal_write on calendar_entries for all
  using (can_publish()) with check (can_publish());

create policy ics_own on ics_tokens for all
  using (member_id = auth.uid()) with check (member_id = auth.uid());

-- ─────────────────────────────────────────────────────────── documents
-- soft delete: members never see deleted rows, staff do (PRD 3.6, 30-day restore)

create policy folders_read on folders for select
  using (auth.uid() is not null);

create policy folders_write on folders for all
  using (is_staff()) with check (is_staff());

create policy docs_read on documents for select
  using (sees(visibility) and (deleted_at is null or is_staff()));

create policy docs_write on documents for all
  using (is_staff() or can_publish()) with check (is_staff() or can_publish());

create policy dv_read on document_versions for select
  using (exists (select 1 from documents d where d.id = document_id));

create policy dv_write on document_versions for all
  using (is_staff() or can_publish()) with check (is_staff() or can_publish());

-- ─────────────────────────────────────────────────────────── newsletter

create policy nl_read on newsletter_issues for select
  using (status = 'published' or can_publish());

create policy nl_write on newsletter_issues for all
  using (can_publish()) with check (can_publish());

create policy nls_insert on newsletter_submissions for insert
  with check (member_id = auth.uid());

create policy nls_read on newsletter_submissions for select
  using (member_id = auth.uid() or can_publish());

-- ─────────────────────────────────────────────────────────── committees (public to members)

create policy terms_read on committee_terms for select using (auth.uid() is not null);
create policy terms_write on committee_terms for all using (is_staff()) with check (is_staff());

create policy comm_read on committees for select using (auth.uid() is not null);
create policy comm_write on committees for all using (is_staff()) with check (is_staff());

create policy cm_read on committee_members for select using (auth.uid() is not null);
create policy cm_write on committee_members for all using (is_staff()) with check (is_staff());

create policy cd_read on committee_documents for select using (auth.uid() is not null);
create policy cd_write on committee_documents for all using (is_staff()) with check (is_staff());

-- ─────────────────────────────────────────────────────────── tickets
-- grievance goes to a restricted queue: office bearers only, not general admin staff (PRD 3.9)

create policy tickets_read on tickets for select
  using (
    member_id = auth.uid()
    or (category = 'grievance' and can_publish())
    or (category <> 'grievance' and is_staff())
  );

create policy tickets_insert on tickets for insert
  with check (member_id = auth.uid());

create policy tickets_staff_update on tickets for update
  using (is_staff() or can_publish()) with check (is_staff() or can_publish());

create policy tm_read on ticket_messages for select
  using (
    (not internal and exists (select 1 from tickets t where t.id = ticket_id))
    or is_staff() or can_publish()
  );

create policy tm_insert on ticket_messages for insert
  with check (author_id = auth.uid());

-- ─────────────────────────────────────────────────────────── notifications

create policy notif_own on notifications for all
  using (member_id = auth.uid()) with check (member_id = auth.uid());

create policy prefs_own on notification_prefs for all
  using (member_id = auth.uid()) with check (member_id = auth.uid());

-- ─────────────────────────────────────────────────────────── audit log
-- readable by staff, writable by nobody: no insert/update/delete policy exists, so the
-- trigger (security definer) is the only way in. That is what "immutable" means here.

create policy audit_read on audit_log for select using (is_staff());

-- ═══════════════════════════════════════════════════════════════
-- 003_functions.sql
-- ═══════════════════════════════════════════════════════════════

-- GHCBA — server-side logic that belongs in the database, not the app.

-- ─────────────────────────────────────────────────────────── login identifier resolution
-- PRD 4.1: login by enrolment number OR registered mobile. Supabase Auth keys on email,
-- so mobile/enrolment are aliases resolved here before signInWithPassword.
-- SECURITY DEFINER + execute-to-anon on purpose: it is called before a session exists.
-- Returns only an email, never confirms whether a password is right.

create or replace function email_for_login(identifier text) returns text
language sql stable security definer set search_path = public as $$
  select email from members
  where enrolment_no = trim(identifier)
     or mobile       = trim(identifier)
     or email        = lower(trim(identifier))
  limit 1;
$$;

revoke all on function email_for_login(text) from public;
grant execute on function email_for_login(text) to anon, authenticated;

-- ─────────────────────────────────────────────────────────── RSVP + waitlist
-- Capacity is a race: two members hitting "Attending" on the last seat must not both win.
-- An advisory lock keyed on the event serialises just that event's RSVPs.
-- ponytail: advisory lock per event; fine to thousands of events, revisit only if a single
-- event sees heavy concurrent RSVP traffic.

create or replace function rsvp_set(p_event bigint, p_status rsvp_status, p_guests int default 0)
returns table (status rsvp_status, waitlisted boolean)
language plpgsql security definer set search_path = public as $$
declare
  ev       events%rowtype;
  taken    int;
  will_wait boolean := false;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select * into ev from events where id = p_event;
  if not found then raise exception 'no such event'; end if;
  if not sees(ev.visibility) then raise exception 'not visible'; end if;
  if ev.rsvp_deadline is not null and now() > ev.rsvp_deadline then
    raise exception 'RSVP closed';
  end if;
  if p_guests > 0 and not ev.allow_guests then
    raise exception 'guests not permitted for this event';
  end if;

  perform pg_advisory_xact_lock(p_event);

  if p_status = 'attending' and ev.capacity is not null then
    select coalesce(sum(1 + guests), 0) into taken
    from event_rsvps
    where event_id = p_event and status = 'attending' and not waitlisted
      and member_id <> auth.uid();

    will_wait := taken + 1 + p_guests > ev.capacity;
  end if;

  insert into event_rsvps as r (event_id, member_id, status, guests, waitlisted)
  values (p_event, auth.uid(), p_status, p_guests, will_wait)
  on conflict (event_id, member_id) do update
    set status = excluded.status,
        guests = excluded.guests,
        waitlisted = excluded.waitlisted,
        updated_at = now();

  -- freeing a seat may let the queue move up
  if p_status <> 'attending' then perform promote_waitlist(p_event); end if;

  return query select p_status, will_wait;
end $$;

-- Promote waitlisted members in arrival order while seats remain (PRD 3.5).
create or replace function promote_waitlist(p_event bigint) returns int
language plpgsql security definer set search_path = public as $$
declare
  ev    events%rowtype;
  taken int;
  r     record;
  n     int := 0;
begin
  select * into ev from events where id = p_event;
  if ev.capacity is null then return 0; end if;

  select coalesce(sum(1 + guests), 0) into taken
  from event_rsvps
  where event_id = p_event and status = 'attending' and not waitlisted;

  for r in
    select member_id, guests from event_rsvps
    where event_id = p_event and status = 'attending' and waitlisted
    order by created_at
  loop
    exit when taken + 1 + r.guests > ev.capacity;

    update event_rsvps set waitlisted = false, updated_at = now()
    where event_id = p_event and member_id = r.member_id;

    insert into notifications (member_id, kind, title, body, link)
    values (r.member_id, 'event', 'A seat opened up',
            'You are now confirmed for ' || ev.title, '/events/' || p_event);

    taken := taken + 1 + r.guests;
    n := n + 1;
  end loop;

  return n;
end $$;

-- ─────────────────────────────────────────────────────────── global search (PRD 4.3)
-- One round trip, results grouped by module in the app. RLS filters each branch, so a
-- committee-only document simply does not come back for a general member.

create or replace function global_search(q text, per_module int default 5)
returns table (module text, id text, title text, snippet text, link text)
language sql stable security definer set search_path = public as $$
  with needle as (select websearch_to_tsquery('english', q) tq, q raw)
  (select 'directory', m.id::text, m.full_name,
          m.enrolment_no || coalesce(' · ' || m.chamber_address, ''), '/directory/' || m.id
   from members m, needle n
   where m.full_name ilike '%' || n.raw || '%'
      or m.enrolment_no ilike '%' || n.raw || '%'
      or m.search_tsv @@ n.tq
   limit per_module)
  union all
  (select 'announcements', a.id::text, a.title, left(a.body, 160), '/announcements/' || a.id
   from announcements a, needle n
   where a.search_tsv @@ n.tq and is_live(a.status, a.publish_at)
   order by a.publish_at desc limit per_module)
  union all
  (select 'documents', d.id::text, d.title, left(coalesce(d.description, ''), 160), '/documents/' || d.id
   from documents d, needle n
   where d.search_tsv @@ n.tq and d.deleted_at is null
   limit per_module)
  union all
  (select 'events', e.id::text, e.title, left(coalesce(e.description, ''), 160), '/events/' || e.id
   from events e, needle n
   where e.search_tsv @@ n.tq
   order by e.starts_at desc limit per_module)
  union all
  (select 'newsletter', i.id::text, i.title, coalesce(i.period, ''), '/newsletter/' || i.id
   from newsletter_issues i, needle n
   where i.status = 'published'
     and (i.title ilike '%' || n.raw || '%' or i.issue_no ilike '%' || n.raw || '%')
   limit per_module);
$$;

-- ─────────────────────────────────────────────────────────── small helpers

create or replace function bump_download(p_doc bigint) returns void
language sql security definer set search_path = public as $$
  update documents set download_count = download_count + 1
  where id = p_doc and deleted_at is null;
$$;

-- unread announcements since the member last looked (PRD 3.1)
create or replace function unread_count() returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int
  from announcements a
  where is_live(a.status, a.publish_at)
    and sees(a.visibility)
    and (a.expires_at is null or a.expires_at > now())
    and not exists (
      select 1 from announcement_reads r
      where r.announcement_id = a.id and r.member_id = auth.uid()
    );
$$;

grant execute on function rsvp_set(bigint, rsvp_status, int)  to authenticated;
grant execute on function global_search(text, int)            to authenticated;
grant execute on function bump_download(bigint)               to authenticated;
grant execute on function unread_count()                      to authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 004_seed.sql
-- ═══════════════════════════════════════════════════════════════

-- GHCBA — demo seed. Creates real auth users so the dashboard is loginable.
-- Every account uses the password: demo1234
-- Safe to re-run: clears seeded rows first.

create extension if not exists pgcrypto with schema extensions;

-- ─────────────────────────────────────────────────────────── reset

truncate table
  announcement_reads, announcement_attachments, announcements,
  event_rsvps, event_gallery, events, calendar_entries, ics_tokens,
  document_versions, committee_documents, documents, folders,
  newsletter_submissions, newsletter_issues,
  committee_members, committees, committee_terms,
  ticket_messages, tickets, notifications, notification_prefs,
  member_profile_changes, member_roles, audit_log
  restart identity cascade;

delete from auth.users where email like '%@ghcba.demo';

-- ─────────────────────────────────────────────────────────── member factory

create or replace function seed_member(
  p_enrol text, p_name text, p_designation designation, p_year int,
  p_mobile text, p_areas text[], p_chamber text,
  p_status membership_status default 'active', p_roles app_role[] default '{member}'
) returns uuid
language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  uid uuid := gen_random_uuid();
  em  text := lower(replace(replace(p_enrol, '/', '-'), ' ', '')) || '@ghcba.demo';
  r   app_role;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
    em, extensions.crypt('demo1234', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', p_name),
    now(), now()
  );

  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), uid, uid::text,
    jsonb_build_object('sub', uid::text, 'email', em), 'email', now(), now(), now()
  );

  insert into members (
    id, enrolment_no, full_name, designation, enrolment_date, mobile, email,
    practice_areas, chamber_address, membership_status, bio
  ) values (
    uid, p_enrol, p_name, p_designation, make_date(p_year, 7, 1), p_mobile, em,
    p_areas, p_chamber, p_status,
    'Practising at the Gauhati High Court since ' || p_year || '.'
  );

  foreach r in array p_roles loop
    insert into member_roles (member_id, role) values (uid, r) on conflict do nothing;
  end loop;

  return uid;
end $$;

-- ─────────────────────────────────────────────────────────── members

do $$
declare
  president uuid; vp uuid; secretary uuid; treasurer uuid; jt_secretary uuid;
  office uuid; ec1 uuid; ec2 uuid; ec3 uuid; ec4 uuid;
  m1 uuid; m2 uuid; m3 uuid; m4 uuid; m5 uuid; m6 uuid; m7 uuid; m8 uuid;
  term_id bigint; c_ob bigint; c_ec bigint; c_lib bigint; c_wel bigint; c_ed bigint;
  ann_id bigint; ev1 bigint; ev2 bigint; ev3 bigint; ev4 bigint;
  f_const bigint; f_circ bigint; f_min bigint; f_forms bigint;
  f_wel bigint; f_elec bigint; f_fin bigint; f_news bigint; f_misc bigint;
  d bigint; nl bigint; tk bigint;
begin

president := seed_member('GHC/1987/012', 'Bhaskar Jyoti Barua', 'senior_advocate', 1987,
  '+919435010012', '{Constitutional,"Land & Revenue",Civil}', 'Chamber 4, Bar Building, Gauhati High Court',
  'active', '{member,office_bearer}');

vp := seed_member('GHC/1991/045', 'Nomita Hazarika', 'senior_advocate', 1991,
  '+919435010045', '{Criminal,"Family Law"}', 'Chamber 11, Bar Building, Gauhati High Court',
  'active', '{member,office_bearer}');

secretary := seed_member('GHC/1995/108', 'Pranab Kumar Das', 'advocate', 1995,
  '+919435010108', '{Service,Constitutional}', 'Chamber 22, Annexe Block, Gauhati High Court',
  'active', '{member,office_bearer}');

treasurer := seed_member('GHC/1998/221', 'Rituparna Saikia', 'advocate', 1998,
  '+919435010221', '{Taxation,Company}', 'Chamber 7, Annexe Block, Gauhati High Court',
  'active', '{member,office_bearer}');

jt_secretary := seed_member('GHC/2001/330', 'Debojit Phukan', 'advocate_on_record', 2001,
  '+919435010330', '{Civil,Arbitration}', 'Chamber 19, Bar Building, Gauhati High Court',
  'active', '{member,office_bearer}');

office := seed_member('GHCBA/OFFICE', 'Association Secretariat', 'advocate', 2010,
  '+919435010000', '{}', 'GHCBA Office, Gauhati High Court, Guwahati 781001',
  'active', '{member,admin,super_admin}');

ec1 := seed_member('GHC/1999/117', 'Jahnabi Goswami', 'advocate', 1999,
  '+919435010117', '{Labour,Service}', 'Chamber 31, Annexe Block', 'active', '{member}');
ec2 := seed_member('GHC/2003/402', 'Aminul Islam', 'advocate', 2003,
  '+919435010402', '{Criminal,"Human Rights"}', 'Chamber 14, Bar Building', 'active', '{member}');
ec3 := seed_member('GHC/2005/511', 'Kaustubh Medhi', 'advocate', 2005,
  '+919435010511', '{Environmental,Civil}', 'Chamber 26, Annexe Block', 'active', '{member}');
ec4 := seed_member('GHC/2007/620', 'Sangeeta Dutta', 'advocate', 2007,
  '+919435010620', '{"Family Law",Civil}', 'Chamber 9, Bar Building', 'active', '{member}');

m1 := seed_member('GHC/2010/733', 'Rupam Bordoloi', 'advocate', 2010,
  '+919435010733', '{Criminal}', 'Chamber 41, Annexe Block', 'active', '{member}');
m2 := seed_member('GHC/2012/845', 'Farhana Ahmed', 'advocate', 2012,
  '+919435010845', '{Constitutional,Service}', 'Chamber 12, Bar Building', 'active', '{member}');
m3 := seed_member('GHC/2014/901', 'Simanta Kalita', 'advocate', 2014,
  '+919435010901', '{Taxation}', 'Chamber 35, Annexe Block', 'active', '{member}');
m4 := seed_member('GHC/2016/044', 'Priyanka Sharma', 'advocate', 2016,
  '+919435010144', '{Civil,Arbitration}', 'Chamber 18, Bar Building', 'active', '{member}');
m5 := seed_member('GHC/2018/156', 'Nabajyoti Deka', 'advocate', 2018,
  '+919435010256', '{"Land & Revenue"}', 'Chamber 29, Annexe Block', 'active', '{member}');
m6 := seed_member('GHC/2020/268', 'Ankita Chetia', 'advocate', 2020,
  '+919435010368', '{Criminal,"Family Law"}', 'Chamber 23, Bar Building', 'active', '{member}');
m7 := seed_member('GHC/1979/003', 'Hemanta Kumar Nath', 'senior_advocate', 1979,
  '+919435010003', '{Constitutional,Civil}', 'Chamber 1, Bar Building', 'life', '{member}');
m8 := seed_member('GHC/1984/008', 'Sushila Rajkhowa', 'senior_advocate', 1984,
  '+919435010008', '{Service,Labour}', 'Chamber 3, Bar Building', 'retired', '{member}');

-- ─────────────────────────────────────────────────────────── committees

insert into committee_terms (label, start_year, end_year, is_current)
values ('2025–2027', 2025, 2027, true) returning id into term_id;

insert into committees (term_id, name, kind, mandate, sort) values
  (term_id, 'Office Bearers', 'office_bearers', 'Executive leadership of the Association.', 1)
  returning id into c_ob;
insert into committees (term_id, name, kind, mandate, sort) values
  (term_id, 'Executive Committee', 'executive', 'General governance and policy of the Association.', 2)
  returning id into c_ec;
insert into committees (term_id, name, kind, mandate, convenor_id, formed_on, sort) values
  (term_id, 'Library Committee', 'standing',
   'Oversees acquisition, cataloguing and upkeep of the Bar Library.', ec3, '2025-04-15', 3)
  returning id into c_lib;
insert into committees (term_id, name, kind, mandate, convenor_id, formed_on, sort) values
  (term_id, 'Welfare Committee', 'standing',
   'Administers the Advocates Welfare Scheme and distress relief to members and dependants.',
   vp, '2025-04-15', 4)
  returning id into c_wel;
insert into committees (term_id, name, kind, mandate, convenor_id, formed_on, sort) values
  (term_id, 'Editorial Committee', 'sub',
   'Publishes the Association newsletter and calls for member contributions.', ec1, '2025-05-02', 5)
  returning id into c_ed;

insert into committee_members (committee_id, member_id, designation, sort) values
  (c_ob, president,    'President', 1),
  (c_ob, vp,           'Vice-President', 2),
  (c_ob, secretary,    'Secretary', 3),
  (c_ob, treasurer,    'Treasurer', 4),
  (c_ob, jt_secretary, 'Joint Secretary', 5),
  (c_ec, ec1, 'Member', 1), (c_ec, ec2, 'Member', 2),
  (c_ec, ec3, 'Member', 3), (c_ec, ec4, 'Member', 4),
  (c_lib, ec3, 'Convenor', 1), (c_lib, m3, 'Member', 2), (c_lib, m4, 'Member', 3),
  (c_wel, vp, 'Convenor', 1), (c_wel, ec4, 'Member', 2), (c_wel, m2, 'Member', 3),
  (c_ed, ec1, 'Convenor', 1), (c_ed, m6, 'Member', 2);

-- prior term, archived and read-only (PRD 3.8 historical view)
insert into committee_terms (label, start_year, end_year, is_current)
values ('2023–2025', 2023, 2025, false);

-- ─────────────────────────────────────────────────────────── announcements

insert into announcements (title, body, category, priority, visibility, status, pinned, publish_at, author_id) values
('Full Court Reference — Hon''ble Mr Justice A. K. Sarma',
 'A Full Court Reference will be held in Court Room No. 1 on Friday at 10:30 AM to bid farewell to the Hon''ble Mr Justice A. K. Sarma on his elevation. All members are requested to attend in court dress.',
 'court_notice', 'important', 'all_members', 'published', true, now() - interval '2 days', secretary),

('Condolence — Late Sri Girish Chandra Bhattacharyya, Senior Advocate',
 'It is with profound sorrow that we record the passing of Sri Girish Chandra Bhattacharyya, Senior Advocate and a former President of this Association, on 28 July 2026. A condolence meeting will be held in the Bar Hall on Monday at 4:00 PM. Members are requested to attend.',
 'condolence', 'important', 'all_members', 'published', true, now() - interval '4 days', president),

('Annual General Meeting — Notice under Rule 12',
 'Notice is hereby given that the Annual General Meeting of the Guwahati High Court Bar Association will be held on 22 August 2026 at 4:00 PM in the Bar Hall. The agenda includes adoption of the audited accounts for 2025–26, the Secretary''s annual report, and consideration of the proposed amendment to Rule 19(b).',
 'meeting_notice', 'urgent', 'all_members', 'published', false, now() - interval '1 day', secretary),

('Advocates Welfare Scheme — last date for 2026–27 contributions',
 'Members are reminded that contributions to the Advocates Welfare Scheme for the year 2026–27 must reach the Association office on or before 31 August 2026. Receipts may be collected from the office between 11:00 AM and 3:00 PM on working days.',
 'welfare_scheme', 'normal', 'all_members', 'published', false, now() - interval '6 days', treasurer),

('Election to the Executive Committee — schedule announced',
 'The election to the Executive Committee for the term 2027–2029 will be held on 14 September 2026. Nominations open on 20 August and close on 30 August 2026. The electoral roll will be published on 18 August.',
 'election', 'important', 'all_members', 'published', false, now() - interval '8 days', secretary),

('Revised chamber allotment — Annexe Block',
 'The revised chamber allotment list for the Annexe Block is available at the Association office. Members with objections may submit them in writing within seven days.',
 'general', 'normal', 'all_members', 'published', false, now() - interval '12 days', office),

('Committee note — draft amendment to Rule 19(b)',
 'Attached for the consideration of committee members is the draft amendment to Rule 19(b) concerning the quorum for requisitioned general meetings, to be placed before the AGM.',
 'general', 'normal', 'committee_only', 'published', false, now() - interval '3 days', secretary),

('Bar Council correspondence — office bearers only',
 'Correspondence received from the Bar Council of Assam, Nagaland, Mizoram, Arunachal Pradesh and Sikkim regarding the verification drive is circulated to office bearers for comment before it is placed before the Executive Committee.',
 'general', 'normal', 'office_bearers_only', 'published', false, now() - interval '5 days', president),

('Court closed — Independence Day',
 'The Court will remain closed on 15 August 2026 on account of Independence Day. The Association office will also remain closed.',
 'court_notice', 'normal', 'all_members', 'published', false, now() - interval '20 days', office),

('Blood donation camp — draft notice for review',
 'Draft notice for the proposed blood donation camp in association with the State Blood Transfusion Council. Awaiting confirmation of date before publication.',
 'general', 'normal', 'all_members', 'draft', false, now(), office);

-- ─────────────────────────────────────────────────────────── events

insert into events (title, description, event_type, starts_at, ends_at, venue, organiser_id,
                    capacity, rsvp_deadline, allow_guests, show_attendees, visibility)
values
('Seminar on the Mediation Act, 2023 — practice and procedure',
 'A half-day seminar examining the working of the Mediation Act, 2023 in the North-East, with sessions on pre-litigation mediation, enforcement of settlement agreements, and the role of the mediator. Hon''ble Mr Justice R. Bhuyan has kindly consented to inaugurate.',
 'seminar', now() + interval '9 days', now() + interval '9 days 4 hours',
 'Bar Hall, Gauhati High Court', secretary, 80, now() + interval '7 days', false, true, 'all_members')
 returning id into ev1;

insert into events (title, description, event_type, starts_at, ends_at, venue, organiser_id,
                    capacity, rsvp_deadline, allow_guests, show_attendees, visibility)
values
('Continuing Legal Education — drafting of writ petitions',
 'A practical workshop for members of under ten years'' standing on the drafting of writ petitions under Articles 226 and 227, conducted by senior members of the Bar. Participants should bring a laptop.',
 'cle_training', now() + interval '18 days', now() + interval '18 days 3 hours',
 'Conference Room, Annexe Block', vp, 30, now() + interval '15 days', false, false, 'all_members')
 returning id into ev2;

insert into events (title, description, event_type, starts_at, ends_at, venue, organiser_id,
                    capacity, rsvp_deadline, allow_guests, show_attendees, visibility)
values
('Bihu celebration and cultural evening',
 'The Association''s annual Bihu celebration. Members are welcome to bring family. Cultural programme by members and their children, followed by dinner.',
 'cultural', now() + interval '30 days', now() + interval '30 days 5 hours',
 'Lawns, Gauhati High Court', ec4, 200, now() + interval '25 days', true, true, 'all_members')
 returning id into ev3;

insert into events (title, description, event_type, starts_at, ends_at, venue, organiser_id, visibility)
values
('Felicitation of Sri Hemanta Kumar Nath on completing 45 years at the Bar',
 'The Association felicitated Sri Hemanta Kumar Nath, Senior Advocate, on the completion of forty-five years of practice at this Court.',
 'felicitation', now() - interval '40 days', now() - interval '40 days' + interval '2 hours',
 'Bar Hall, Gauhati High Court', president, 'all_members')
 returning id into ev4;

update events set outcome_note =
  'The felicitation was attended by over 120 members. The President read the citation and a memento was presented.'
where id = ev4;

insert into event_rsvps (event_id, member_id, status, guests) values
  (ev1, m1, 'attending', 0), (ev1, m2, 'attending', 0), (ev1, m4, 'maybe', 0),
  (ev1, ec1, 'attending', 0), (ev1, ec2, 'not_attending', 0),
  (ev2, m5, 'attending', 0), (ev2, m6, 'attending', 0),
  (ev3, m1, 'attending', 2), (ev3, ec4, 'attending', 3);

-- ─────────────────────────────────────────────────────────── calendar

insert into calendar_entries (title, entry_type, starts_at, ends_at, all_day, description) values
  ('Independence Day — Court closed', 'court_holiday', date_trunc('day', now()) + interval '12 days',
   date_trunc('day', now()) + interval '12 days', true, 'Gazetted holiday.'),
  ('Janmashtami — Court closed', 'court_holiday', date_trunc('day', now()) + interval '23 days',
   date_trunc('day', now()) + interval '23 days', true, 'Gazetted holiday.'),
  ('Puja vacation begins', 'court_holiday', date_trunc('day', now()) + interval '60 days',
   date_trunc('day', now()) + interval '74 days', true, 'Annual Puja vacation.'),
  ('Executive Committee meeting', 'association_meeting', date_trunc('day', now()) + interval '3 days' + interval '16 hours',
   date_trunc('day', now()) + interval '3 days' + interval '18 hours', false, 'Monthly meeting of the Executive Committee.'),
  ('Annual General Meeting', 'gbm_egm', date_trunc('day', now()) + interval '19 days' + interval '16 hours',
   date_trunc('day', now()) + interval '19 days' + interval '19 hours', false, 'AGM under Rule 12.'),
  ('Election — Executive Committee 2027–2029', 'election', date_trunc('day', now()) + interval '42 days' + interval '9 hours',
   date_trunc('day', now()) + interval '42 days' + interval '17 hours', false, 'Polling in the Bar Hall.'),
  ('Condolence meeting — Late Sri G. C. Bhattacharyya', 'association_meeting',
   date_trunc('day', now()) + interval '1 day' + interval '16 hours',
   date_trunc('day', now()) + interval '1 day' + interval '17 hours', false, 'Bar Hall.');

insert into calendar_entries (title, entry_type, starts_at, ends_at, event_id, description)
select e.title, 'event', e.starts_at, e.ends_at, e.id, left(e.description, 200)
from events e where e.starts_at > now();

-- ─────────────────────────────────────────────────────────── documents

insert into folders (name, sort) values
  ('Constitution & Bye-Laws', 1) returning id into f_const;
insert into folders (name, sort) values ('Circulars & Notifications', 2) returning id into f_circ;
insert into folders (name, sort) values ('Minutes of Meetings', 3)      returning id into f_min;
insert into folders (name, sort) values ('Forms & Applications', 4)     returning id into f_forms;
insert into folders (name, sort) values ('Welfare Scheme', 5)           returning id into f_wel;
insert into folders (name, sort) values ('Election Records', 6)         returning id into f_elec;
insert into folders (name, sort) values ('Financial Statements', 7)     returning id into f_fin;
insert into folders (name, sort) values ('Newsletter Archive', 8)       returning id into f_news;
insert into folders (name, sort) values ('Miscellaneous', 9)            returning id into f_misc;

insert into folders (name, parent_id, sort) values
  ('2026', f_min, 1), ('2025', f_min, 2), ('2024', f_min, 3);

-- helper: document + its first version
create or replace function seed_doc(
  p_title text, p_desc text, p_folder bigint, p_tags text[],
  p_vis visibility, p_uploader uuid, p_file text, p_size bigint
) returns bigint
language plpgsql security definer set search_path = public as $$
declare did bigint;
begin
  insert into documents (title, description, folder_id, tags, visibility, uploader_id, download_count)
  values (p_title, p_desc, p_folder, p_tags, p_vis, p_uploader, floor(random() * 90)::int)
  returning id into did;

  insert into document_versions (document_id, version, file_path, file_name, size_bytes, mime_type, uploaded_by)
  values (did, 1, 'demo/' || p_file, p_file, p_size, 'application/pdf', p_uploader);

  return did;
end $$;

perform seed_doc('Constitution of the Guwahati High Court Bar Association',
  'The Constitution as amended up to the General Body Meeting of 12 March 2024.',
  f_const, '{constitution,bye-laws,governing}', 'all_members', office, 'ghcba-constitution-2024.pdf', 1842000);

perform seed_doc('Bye-Laws — consolidated text',
  'Consolidated bye-laws incorporating all amendments to date.',
  f_const, '{bye-laws,rules}', 'all_members', office, 'ghcba-byelaws-consolidated.pdf', 964000);

perform seed_doc('Circular 14/2026 — chamber allotment, Annexe Block',
  'Revised chamber allotment list for the Annexe Block with objection procedure.',
  f_circ, '{circular,chambers,allotment}', 'all_members', office, 'circular-14-2026.pdf', 320000);

perform seed_doc('Circular 11/2026 — court dress during vacation sittings',
  'Clarification on court dress requirements for vacation bench sittings.',
  f_circ, '{circular,court-dress}', 'all_members', office, 'circular-11-2026.pdf', 210000);

perform seed_doc('Minutes — Executive Committee, 18 July 2026',
  'Minutes of the monthly meeting of the Executive Committee.',
  f_min, '{minutes,executive-committee,2026}', 'committee_only', secretary, 'ec-minutes-2026-07-18.pdf', 445000);

perform seed_doc('Minutes — Executive Committee, 20 June 2026',
  'Minutes of the monthly meeting of the Executive Committee.',
  f_min, '{minutes,executive-committee,2026}', 'committee_only', secretary, 'ec-minutes-2026-06-20.pdf', 402000);

perform seed_doc('Minutes — Annual General Meeting, 24 August 2025',
  'Minutes of the AGM including adoption of accounts for 2024–25.',
  f_min, '{minutes,agm,2025}', 'all_members', secretary, 'agm-minutes-2025.pdf', 688000);

perform seed_doc('Form A — application for membership',
  'Application form for enrolment as a member of the Association.',
  f_forms, '{form,membership,application}', 'all_members', office, 'form-a-membership.pdf', 180000);

perform seed_doc('Form W-1 — Welfare Scheme claim',
  'Claim form under the Advocates Welfare Scheme, to be submitted with supporting documents.',
  f_forms, '{form,welfare,claim}', 'all_members', office, 'form-w1-welfare-claim.pdf', 195000);

perform seed_doc('Form C — change of chamber address',
  'Form for intimating a change of chamber address to the Association office.',
  f_forms, '{form,address,chamber}', 'all_members', office, 'form-c-address-change.pdf', 142000);

perform seed_doc('Advocates Welfare Scheme — rules and benefits',
  'Full text of the Welfare Scheme rules, contribution rates and schedule of benefits.',
  f_wel, '{welfare,scheme,rules,benefits}', 'all_members', treasurer, 'welfare-scheme-rules.pdf', 1120000);

perform seed_doc('Welfare Scheme — statement of disbursements 2025–26',
  'Statement of disbursements made under the Welfare Scheme during 2025–26.',
  f_wel, '{welfare,disbursement,2025-26}', 'committee_only', treasurer, 'welfare-disbursements-2025-26.pdf', 530000);

perform seed_doc('Electoral roll — Executive Committee election 2025',
  'Final electoral roll published for the 2025 Executive Committee election.',
  f_elec, '{election,electoral-roll,2025}', 'all_members', secretary, 'electoral-roll-2025.pdf', 2340000);

perform seed_doc('Election result — Executive Committee 2025–2027',
  'Declaration of results of the election held on 15 September 2025.',
  f_elec, '{election,result,2025}', 'all_members', secretary, 'election-result-2025.pdf', 288000);

perform seed_doc('Audited accounts 2024–25',
  'Audited statement of accounts of the Association for the financial year 2024–25.',
  f_fin, '{accounts,audit,2024-25}', 'all_members', treasurer, 'audited-accounts-2024-25.pdf', 1480000);

perform seed_doc('Budget estimate 2026–27',
  'Budget estimate placed before the Executive Committee for approval.',
  f_fin, '{budget,2026-27}', 'office_bearers_only', treasurer, 'budget-estimate-2026-27.pdf', 640000);

perform seed_doc('Bar Library — accession register, 2026',
  'Register of books and journals accessioned into the Bar Library during 2026.',
  f_misc, '{library,accession,register}', 'all_members', ec3, 'library-accession-2026.pdf', 760000);

-- ─────────────────────────────────────────────────────────── newsletter

insert into newsletter_issues (issue_no, title, period, editorial, pdf_path, status, published_at)
values
('Vol. XII, No. 3', 'The Gauhati Bar Review', 'July 2026',
 'This issue carries a note on the working of the Mediation Act in the North-East, a tribute to Sri G. C. Bhattacharyya, and the Secretary''s report for the quarter.',
 'demo/gauhati-bar-review-2026-07.pdf', 'published', now() - interval '10 days')
 returning id into nl;

insert into newsletter_issues (issue_no, title, period, editorial, pdf_path, status, published_at) values
('Vol. XII, No. 2', 'The Gauhati Bar Review', 'April 2026',
 'A special number on the centenary of the Gauhati High Court Bar Association, with archival photographs and recollections from senior members.',
 'demo/gauhati-bar-review-2026-04.pdf', 'published', now() - interval '100 days'),
('Vol. XII, No. 1', 'The Gauhati Bar Review', 'January 2026',
 'The New Year number, carrying the President''s message and a review of significant judgments of 2025.',
 'demo/gauhati-bar-review-2026-01.pdf', 'published', now() - interval '190 days'),
('Vol. XI, No. 4', 'The Gauhati Bar Review', 'October 2025',
 'The Puja number, with a symposium on arbitration practice in Assam.',
 'demo/gauhati-bar-review-2025-10.pdf', 'published', now() - interval '280 days');

-- newsletters are indexed into the Document Library automatically (PRD 3.7 acceptance criteria)
insert into documents (title, description, folder_id, tags, visibility, uploader_id)
select i.title || ' — ' || i.period, coalesce(i.editorial, ''), f_news,
       array['newsletter', lower(replace(i.period, ' ', '-'))], 'all_members', office
from newsletter_issues i where i.status = 'published';

update newsletter_issues i set document_id = d.id
from documents d where d.folder_id = f_news and d.title = i.title || ' — ' || i.period;

insert into document_versions (document_id, version, file_path, file_name, size_bytes, mime_type, uploaded_by)
select d.id, 1, i.pdf_path, split_part(i.pdf_path, '/', 2), 4200000, 'application/pdf', office
from documents d join newsletter_issues i on i.document_id = d.id;

-- ─────────────────────────────────────────────────────────── tickets

insert into tickets (member_id, category, subject, message, status, assigned_to)
values (m3, 'membership', 'Correction of enrolment date in the directory',
        'My enrolment date is shown as 1 July 2014 whereas the correct date is 14 August 2014. Kindly have the record corrected.',
        'in_progress', office)
 returning id into tk;

insert into ticket_messages (ticket_id, author_id, body, internal) values
 (tk, office, 'We have retrieved the enrolment register and are verifying the entry. We will revert shortly.', false),
 (tk, office, 'Register page 214 confirms 14 August 2014. Awaiting Secretary''s approval to amend.', true);

insert into tickets (member_id, category, subject, message, status) values
 (m6, 'welfare_scheme', 'Welfare Scheme — receipt not received',
  'I remitted the 2026–27 contribution on 12 July by NEFT but have not received a receipt. UTR is attached in the message body: SBIN226420981.', 'open'),
 (m1, 'technical_support', 'Unable to download the audited accounts',
  'The link to the audited accounts for 2024–25 returns an error on my phone.', 'resolved'),
 (m2, 'grievance', 'Chamber allotment objection',
  'I wish to record an objection to the revised chamber allotment in the Annexe Block. My application of seniority appears to have been overlooked.', 'open');

-- ─────────────────────────────────────────────────────────── notifications

insert into notifications (member_id, kind, title, body, link, created_at)
select m.id, 'announcement', 'New notice: Annual General Meeting',
       'Notice under Rule 12 for the AGM on 22 August 2026.', '/announcements', now() - interval '1 day'
from members m;

insert into notifications (member_id, kind, title, body, link, created_at)
select m.id, 'newsletter', 'The Gauhati Bar Review — July 2026 is out',
       'Vol. XII, No. 3 is now available to read.', '/newsletter', now() - interval '10 days'
from members m;

end $$;

drop function if exists seed_member(text, text, designation, int, text, text[], text, membership_status, app_role[]);
drop function if exists seed_doc(text, text, bigint, text[], visibility, uuid, text, bigint);

-- ─────────────────────────────────────────────────────────── verify

do $$
declare n_members int; n_ann int; n_docs int; n_ev int;
begin
  select count(*) into n_members from members;
  select count(*) into n_ann from announcements;
  select count(*) into n_docs from documents;
  select count(*) into n_ev from events;
  raise notice 'seeded: % members, % announcements, % documents, % events', n_members, n_ann, n_docs, n_ev;
  assert n_members >= 19, 'member seed failed';
  assert n_ann >= 10, 'announcement seed failed';
  assert n_docs >= 20, 'document seed failed';
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 005_check.sql
-- ═══════════════════════════════════════════════════════════════

-- One runnable check for the thing most likely to be quietly wrong: visibility.
-- Asserts PRD 3.6 — "a Committee Only document never appears in a general member's
-- search results" — and its office-bearer sibling, by impersonating real members.
-- Run after 004_seed.sql. Raises an exception on failure; prints OK on success.

do $$
declare
  plain_member  uuid;
  committee_guy uuid;
  bearer        uuid;
  n int;
begin
  -- a member on no committee
  select m.id into plain_member
  from members m
  where m.enrolment_no = 'GHC/2010/733';

  -- a member on a current-term committee but not an office bearer
  select m.id into committee_guy
  from members m where m.enrolment_no = 'GHC/2005/511';

  select m.id into bearer
  from members m where m.enrolment_no = 'GHC/1995/108';

  -- ── plain member sees no restricted documents ──────────────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', plain_member, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into n from documents where visibility <> 'all_members';
  assert n = 0, format('plain member can see %s restricted documents (expected 0)', n);

  select count(*) into n from announcements where visibility <> 'all_members';
  assert n = 0, format('plain member can see %s restricted announcements (expected 0)', n);

  select count(*) into n from documents where visibility = 'all_members';
  assert n > 0, 'plain member cannot see ordinary documents — RLS is too tight';

  reset role;

  -- ── committee member sees committee_only but not office_bearers_only ───
  perform set_config('request.jwt.claims',
    json_build_object('sub', committee_guy, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into n from documents where visibility = 'committee_only';
  assert n > 0, 'committee member cannot see committee_only documents';

  select count(*) into n from documents where visibility = 'office_bearers_only';
  assert n = 0, format('committee member can see %s office-bearer documents (expected 0)', n);

  reset role;

  -- ── office bearer sees everything ─────────────────────────────────────
  perform set_config('request.jwt.claims',
    json_build_object('sub', bearer, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into n from documents where visibility = 'office_bearers_only';
  assert n > 0, 'office bearer cannot see office_bearers_only documents';

  reset role;

  raise notice 'RLS visibility checks passed.';
end $$;
