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
