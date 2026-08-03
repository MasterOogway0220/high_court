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
