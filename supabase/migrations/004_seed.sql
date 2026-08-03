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

-- helper: document + its first version.
-- Defined out here, not inside the seeding block below: a $$-quoted function body
-- nested inside a $$-quoted DO block terminates the outer block at its first $$.
create or replace function seed_doc(
  p_title text, p_desc text, p_folder bigint, p_tags text[],
  p_vis visibility, p_uploader uuid, p_file text, p_size bigint
) returns bigint
language plpgsql security definer set search_path = public as $fn$
declare did bigint;
begin
  insert into documents (title, description, folder_id, tags, visibility, uploader_id, download_count)
  values (p_title, p_desc, p_folder, p_tags, p_vis, p_uploader, floor(random() * 90)::int)
  returning id into did;

  insert into document_versions (document_id, version, file_path, file_name, size_bytes, mime_type, uploaded_by)
  values (did, 1, 'demo/' || p_file, p_file, p_size, 'application/pdf', p_uploader);

  return did;
end $fn$;

-- ─────────────────────────────────────────────────────────── members

do $seed$
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

end $seed$;

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
