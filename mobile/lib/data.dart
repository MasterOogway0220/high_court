import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/*
  The app talks to Supabase directly with the anon key, exactly as the web app's
  browser client does. Row-level security is the authorisation boundary in both —
  there is no privileged path here, and no second API to keep in step.
*/

// Public config. The anon key is the same value the web app serves to every
// browser: safe to ship, RLS applies. Overridable at build time with
//   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://lxqhenipubmjfsjatipw.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4cWhlbmlwdWJtamZzamF0aXB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzQ3ODgsImV4cCI6MjEwMTMxMDc4OH0.kn_aIRwnIRI77o928hqZnjvwFYiQZ9R-_uGR1sw2RfI',
);

/*
  Demo auto-login, mirroring DEMO_AUTO_LOGIN in src/proxy.ts. When an account is
  configured the app signs in as it at launch and the sign-in gate never appears,
  so the dashboard can be shown without a sign-in step.

  Gated on a compile-time value rather than hard-coded, exactly as the web gates
  it on an env var: build with --dart-define=DEMO_AUTO_LOGIN= and the normal gate
  returns, with no code change. Never ship this to members — it hands every
  person holding the APK a full session.
*/
const demoEmail = String.fromEnvironment(
  'DEMO_AUTO_LOGIN',
  defaultValue: 'ghcba-office@ghcba.demo',
);
const demoPassword = String.fromEnvironment(
  'DEMO_AUTO_LOGIN_PASSWORD',
  defaultValue: 'demo1234',
);

bool get demoMode => demoEmail.isNotEmpty;

SupabaseClient get sb => Supabase.instance.client;

/// One record from Postgres. Named Rec, not Row — Flutter already owns `Row`.
typedef Rec = Map<String, dynamic>;

List<Rec> _rows(dynamic v) =>
    (v as List? ?? const []).cast<Rec>().toList(growable: false);

String nowIso() => DateTime.now().toUtc().toIso8601String();

/// The signed-in member, with roles — mirrors me() in src/lib/supabase/server.ts.
class Me {
  Me(this.row, this.roles);

  final Rec row;
  final List<String> roles;

  String get id => row['id'] as String;
  String get fullName => (row['full_name'] ?? '') as String;
  String get enrolmentNo => (row['enrolment_no'] ?? '') as String;
  String? get email => row['email'] as String?;
  String? get photoUrl => row['photo_url'] as String?;
  String get status => (row['membership_status'] ?? '') as String;

  bool get canPublish => roles.any(
    (r) => const {'office_bearer', 'admin', 'super_admin'}.contains(r),
  );
  bool get isStaff =>
      roles.any((r) => const {'admin', 'super_admin'}.contains(r));
}

class Data {
  Data._();

  // ── Auth ────────────────────────────────────────────────────────────────

  /// PRD 4.1: members sign in with an enrolment number or registered mobile,
  /// neither of which Supabase Auth understands. One resolver, as on the web.
  /// Returns an error message, or null on success.
  static Future<String?> signIn(String identifier, String password) async {
    final id = identifier.trim();
    if (id.isEmpty || password.isEmpty) {
      return 'Enter your enrolment number and password.';
    }

    String? email;
    try {
      final res = await sb.rpc('email_for_login', params: {'identifier': id});
      email = res as String?;
    } catch (_) {
      // A failed lookup and an unknown member are different faults with
      // different fixes — do not report one as the other.
      return 'Sign-in is unavailable — the directory could not be reached. '
          'Contact the Association office.';
    }

    if (email == null || email.isEmpty) {
      return 'No member found with that enrolment number or mobile number.';
    }

    try {
      await sb.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException {
      return 'That password does not match our records.';
    } catch (_) {
      return 'Could not sign in. Check your connection and try again.';
    }
  }

  /// Returns false rather than throwing: a failed demo sign-in falls back to the
  /// normal gate. The web learned this the hard way — bouncing on failure turned
  /// a bad password into ERR_TOO_MANY_REDIRECTS instead of a legible error.
  static Future<bool> demoSignIn() async {
    if (!demoMode) return false;
    try {
      await sb.auth.signInWithPassword(
        email: demoEmail,
        password: demoPassword,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() => sb.auth.signOut();

  static Future<Me?> me() async {
    final user = sb.auth.currentUser;
    if (user == null) return null;

    final results = await Future.wait<dynamic>([
      sb.from('members').select().eq('id', user.id).maybeSingle(),
      sb.from('member_roles').select('role').eq('member_id', user.id),
    ]);

    final member = results[0] as Rec?;
    if (member == null) return null;

    final roles = _rows(
      results[1],
    ).map((r) => r['role'] as String).toList(growable: false);
    return Me(member, roles);
  }

  // ── Dashboard ───────────────────────────────────────────────────────────

  /// An exact count without hauling the rows back: PostgREST reports the count
  /// over the whole filtered set, so limit(1) keeps the payload to one row.
  static Future<int> _count(PostgrestTransformBuilder<PostgrestList> q) async {
    final res = await q.limit(1).count(CountOption.exact);
    return res.count;
  }

  static Future<int> unreadNotices() async {
    final v = await sb.rpc('unread_count');
    return (v as num?)?.toInt() ?? 0;
  }

  static Future<int> weekEntries() {
    final now = DateTime.now().toUtc();
    return _count(
      sb
          .from('calendar_entries')
          .select('id')
          .gte('starts_at', now.toIso8601String())
          .lte(
            'starts_at',
            now.add(const Duration(days: 7)).toIso8601String(),
          ),
    );
  }

  static Future<int> openEvents() => _count(
    sb.from('events').select('id').gte('starts_at', nowIso()),
  );

  static Future<int> membersOnRoll() => _count(
    sb.from('members').select('id').inFilter('membership_status', [
      'active',
      'life',
    ]),
  );

  static Future<int> unreadNotifications() =>
      _count(sb.from('notifications').select('id').isFilter('read_at', null));

  // ── Announcements ───────────────────────────────────────────────────────

  static Future<List<Rec>> announcements({
    String? q,
    String? category,
    bool archive = false,
    int limit = 60,
  }) async {
    final now = nowIso();
    var query = sb
        .from('announcements')
        .select(
          'id, title, body, category, priority, visibility, pinned, publish_at, '
          'expires_at, announcement_attachments(id), announcement_reads(member_id)',
        )
        .eq('status', 'published')
        .lte('publish_at', now);

    // PRD 3.3: expired notices leave the feed but stay in the archive.
    if (!archive) query = query.or('expires_at.is.null,expires_at.gt.$now');
    if (q != null && q.trim().isNotEmpty) {
      final t = q.trim();
      query = query.or('title.ilike.%$t%,body.ilike.%$t%');
    }
    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    return _rows(
      await query
          .order('pinned', ascending: false)
          .order('publish_at', ascending: false)
          .limit(limit),
    );
  }

  static Future<Rec?> announcement(int id) async =>
      await sb
              .from('announcements')
              .select(
                '*, members(full_name), announcement_attachments(*)',
              )
              .eq('id', id)
              .maybeSingle();

  static Future<void> markRead(int announcementId, String memberId) async {
    // Reading the same notice twice is not an error; the PK absorbs it.
    await sb.from('announcement_reads').upsert({
      'announcement_id': announcementId,
      'member_id': memberId,
    }, onConflict: 'announcement_id,member_id', ignoreDuplicates: true);
  }

  // ── Calendar ────────────────────────────────────────────────────────────

  static Future<List<Rec>> calendar({
    required DateTime from,
    required DateTime to,
    String? type,
  }) async {
    var q = sb
        .from('calendar_entries')
        .select(
          'id, title, entry_type, starts_at, ends_at, all_day, description, event_id',
        )
        .gte('starts_at', from.toUtc().toIso8601String())
        .lte('starts_at', to.toUtc().toIso8601String());
    if (type != null && type.isNotEmpty) q = q.eq('entry_type', type);
    return _rows(await q.order('starts_at'));
  }

  // ── Events ──────────────────────────────────────────────────────────────

  static Future<List<Rec>> events({bool past = false, int limit = 40}) async {
    final base = sb
        .from('events')
        .select(
          'id, title, description, event_type, starts_at, venue, capacity, '
          'banner_url, event_rsvps(status, guests, waitlisted, member_id)',
        );
    final filtered = past
        ? base.lt('starts_at', nowIso())
        : base.gte('starts_at', nowIso());
    return _rows(
      await filtered.order('starts_at', ascending: !past).limit(limit),
    );
  }

  static Future<Rec?> event(int id) async =>
      await sb
              .from('events')
              .select(
                '*, members(full_name), event_rsvps(status, guests, waitlisted, member_id, '
                'members(id, full_name, enrolment_no, photo_url))',
              )
              .eq('id', id)
              .maybeSingle();

  /// RLS decides what comes back: own row always, everyone's only if the
  /// organiser opened the list or the viewer is an office bearer (PRD 3.5).
  static Future<List<Rec>> eventRsvps(int eventId) => sb
      .from('event_rsvps')
      .select(
        'member_id, status, guests, waitlisted, '
        'members(id, full_name, enrolment_no, photo_url)',
      )
      .eq('event_id', eventId)
      .then(_rows);

  /// PRD 3.5. The RPC owns capacity and the waitlist, so the app never decides
  /// whether a place exists — it asks, and renders what came back.
  static Future<Rec?> setRsvp(int eventId, String status, int guests) async {
    final res = await sb.rpc(
      'rsvp_set',
      params: {'p_event': eventId, 'p_status': status, 'p_guests': guests},
    );
    final rows = _rows(res);
    return rows.isEmpty ? null : rows.first;
  }

  // ── Directory ───────────────────────────────────────────────────────────

  static Future<List<Rec>> members({
    String? q,
    String? area,
    String? designation,
    String? status,
    String sort = 'name',
    int limit = 300,
  }) async {
    var query = sb
        .from('members')
        .select(
          'id, enrolment_no, full_name, designation, enrolment_date, practice_areas, '
          'chamber_address, membership_status, photo_url, mobile, email, hide_mobile, hide_email',
        );

    // PRD 3.2: search across name, enrolment number and chamber location.
    if (q != null && q.trim().isNotEmpty) {
      final t = q.trim();
      query = query.or(
        'full_name.ilike.%$t%,enrolment_no.ilike.%$t%,chamber_address.ilike.%$t%',
      );
    }
    if (area != null && area.isNotEmpty) {
      query = query.contains('practice_areas', [area]);
    }
    if (designation != null && designation.isNotEmpty) {
      query = query.eq('designation', designation);
    }
    if (status != null && status.isNotEmpty) {
      query = query.eq('membership_status', status);
    }

    final ordered = switch (sort) {
      'year' => query.order('enrolment_date', ascending: true),
      'recent' => query.order('enrolment_date', ascending: false),
      _ => query.order('full_name', ascending: true),
    };

    return _rows(await ordered.limit(limit));
  }

  static Future<Rec?> member(String id) async =>
      await sb.from('members').select().eq('id', id).maybeSingle();

  static Future<List<Rec>> memberPositions(String id) => sb
      .from('committee_members')
      .select(
        'designation, committees(id, name, kind, committee_terms(label, is_current))',
      )
      .eq('member_id', id)
      .then(_rows);

  // ── Documents ───────────────────────────────────────────────────────────

  static Future<List<Rec>> folders() => sb
      .from('folders')
      .select()
      .isFilter('parent_id', null)
      .order('sort')
      .then(_rows);

  static Future<List<Rec>> documents({
    String? q,
    int? folderId,
    int limit = 100,
  }) async {
    var query = sb
        .from('documents')
        .select(
          'id, title, description, tags, visibility, download_count, created_at, '
          'folder_id, folders(name), document_versions(version, size_bytes, file_name)',
        )
        .isFilter('deleted_at', null);

    if (q != null && q.trim().isNotEmpty) {
      final t = q.trim();
      query = query.or('title.ilike.%$t%,description.ilike.%$t%');
    }
    if (folderId != null) query = query.eq('folder_id', folderId);

    return _rows(await query.order('created_at', ascending: false).limit(limit));
  }

  static Future<Rec?> document(int id) async =>
      await sb
              .from('documents')
              .select(
                '*, folders(name), members(full_name), '
                'document_versions(*, members(full_name))',
              )
              .eq('id', id)
              .maybeSingle();

  /// The bucket is private, so a file is reached through a short-lived signed
  /// URL. Storage RLS re-checks visibility, so a link cannot outlive permission.
  static Future<String?> signedUrl(String path, {int seconds = 300}) async {
    try {
      return await sb.storage.from('documents').createSignedUrl(path, seconds);
    } catch (_) {
      return null;
    }
  }

  // ── Newsletter ──────────────────────────────────────────────────────────

  static Future<List<Rec>> newsletters({int limit = 30}) => sb
      .from('newsletter_issues')
      .select()
      .eq('status', 'published')
      .order('published_at', ascending: false)
      .limit(limit)
      .then(_rows);

  static Future<Rec?> newsletter(int id) async =>
      await sb.from('newsletter_issues').select().eq('id', id).maybeSingle();

  // ── Committee ───────────────────────────────────────────────────────────

  static Future<List<Rec>> committeeTerms() => sb
      .from('committee_terms')
      .select()
      .order('start_year', ascending: false)
      .then(_rows);

  static Future<List<Rec>> committees(int termId) => sb
      .from('committees')
      .select(
        '*, members(id, full_name), committee_members(designation, sort, '
        'members(id, full_name, enrolment_no, photo_url, designation))',
      )
      .eq('term_id', termId)
      .order('sort')
      .then(_rows);

  static Future<Rec?> committee(int id) async =>
      await sb
              .from('committees')
              .select(
                '*, members(id, full_name), committee_terms(label, is_current), '
                'committee_members(designation, sort, members(id, full_name, '
                'enrolment_no, photo_url, designation))',
              )
              .eq('id', id)
              .maybeSingle();

  static Future<List<Rec>> committeeDocuments(int committeeId) => sb
      .from('committee_documents')
      .select('documents(id, title, created_at)')
      .eq('committee_id', committeeId)
      .then(_rows);

  // ── Notifications ───────────────────────────────────────────────────────

  static Future<List<Rec>> notifications({int limit = 50}) => sb
      .from('notifications')
      .select()
      .order('created_at', ascending: false)
      .limit(limit)
      .then(_rows);

  static Future<void> markAllNotificationsRead(String memberId) => sb
      .from('notifications')
      .update({'read_at': nowIso()})
      .eq('member_id', memberId)
      .isFilter('read_at', null);

  // ── Settings ────────────────────────────────────────────────────────────

  static Future<Rec?> icsToken() async =>
      await sb
              .from('ics_tokens')
              .select('token')
              .eq('revoked', false)
              .limit(1)
              .maybeSingle();

  /// PRD 3.2: contact details, bio, practice areas and privacy are self-service.
  static Future<void> saveProfile({
    required String memberId,
    required String mobile,
    required String chamberPhone,
    required String chamberAddress,
    required String bio,
    required List<String> practiceAreas,
    required bool hideMobile,
    required bool hideEmail,
  }) => sb
      .from('members')
      .update({
        'mobile': mobile.trim().isEmpty ? null : mobile.trim(),
        'chamber_phone': chamberPhone.trim().isEmpty
            ? null
            : chamberPhone.trim(),
        'chamber_address': chamberAddress.trim().isEmpty
            ? null
            : chamberAddress.trim(),
        'bio': bio.trim().isEmpty
            ? null
            : bio.trim().substring(0, bio.trim().length.clamp(0, 500)),
        'practice_areas': practiceAreas,
        'hide_mobile': hideMobile,
        'hide_email': hideEmail,
      })
      .eq('id', memberId);

  /// Name, enrolment number and designation never write straight through —
  /// they go to the office's moderation queue (PRD 3.2).
  static Future<void> requestProfileChange({
    required String memberId,
    required String field,
    required String oldValue,
    required String newValue,
  }) => sb.from('member_profile_changes').insert({
    'member_id': memberId,
    'field': field,
    'old_value': oldValue,
    'new_value': newValue,
  });

  static Future<List<Rec>> pendingChanges(String memberId) => sb
      .from('member_profile_changes')
      .select('field, new_value')
      .eq('member_id', memberId)
      .eq('status', 'pending')
      .then(_rows);

  static Future<List<Rec>> notificationPrefs() =>
      sb.from('notification_prefs').select().then(_rows);

  static Future<void> setNotificationPref({
    required String memberId,
    required String category,
    required bool enabled,
  }) => sb.from('notification_prefs').upsert({
    'member_id': memberId,
    'category': category,
    'email_enabled': enabled,
  }, onConflict: 'member_id,category');

  /// Anyone holding the feed URL can read the member's calendar, so rotating
  /// must revoke the old token in the same breath as issuing the new one.
  static Future<void> rotateIcsToken(String memberId) async {
    await sb
        .from('ics_tokens')
        .update({'revoked': true})
        .eq('member_id', memberId);
    await sb.from('ics_tokens').insert({
      'token': _token(),
      'member_id': memberId,
    });
  }

  static String _token() {
    final r = Random.secure();
    return List.generate(
      32,
      (_) => '0123456789abcdef'[r.nextInt(16)],
    ).join();
  }
}
