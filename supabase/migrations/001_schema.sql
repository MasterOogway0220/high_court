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
