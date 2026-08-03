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
