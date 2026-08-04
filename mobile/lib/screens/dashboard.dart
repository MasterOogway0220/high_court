import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'announcement_detail.dart';
import 'calendar.dart';
import 'chrome.dart';
import 'committee.dart';
import 'document_detail.dart';
import 'event_detail.dart';
import 'newsletter.dart';
import 'settings.dart';

/// Mirrors src/app/(app)/page.tsx — the day's business, then five widgets, each
/// loading on its own so a slow query degrades to a skeleton (PRD 3.1).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.me, required this.onGo});

  final Me me;
  final void Function(int tab) onGo;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _token = 0;

  Future<void> _refresh() async => setState(() => _token++);

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final first = me.fullName.split(' ').first;
    final live = me.status == 'active' || me.status == 'life';

    return Column(
      children: [
        Loader<int>(
          key: ValueKey('notif-$_token'),
          load: Data.unreadNotifications,
          placeholder: AppHeader(me: me),
          builder: (_, n) => AppHeader(me: me, unread: n),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: C.ink,
            backgroundColor: C.surface,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 32),
              children: [
                Text('$greeting,', style: T.largeTitle),
                Text(first, style: T.largeTitle),
                const SizedBox(height: 8),
                Text(
                  '${dayOfWeekLine(now)} · here is what the Association has on today.',
                  style: T.subhead,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Tag(me.enrolmentNo),
                    const SizedBox(width: 6),
                    Tag(
                      humanise(me.status),
                      tone: live ? Tone.success : Tone.warn,
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                _stats(),
                const SizedBox(height: 24),

                SectionHeader(
                  'Latest notices',
                  onMore: () => widget.onGo(1),
                ),
                Loader<List<Rec>>(
                  key: ValueKey('ann-$_token'),
                  load: () => Data.announcements(limit: 3),
                  builder: (_, rows) => _latestNotices(rows),
                ),
                const SizedBox(height: 24),

                SectionHeader(
                  'Today & this week',
                  onMore: () => _push(const CalendarScreen()),
                ),
                Loader<List<Rec>>(
                  key: ValueKey('cal-$_token'),
                  load: () => Data.calendar(
                    from: DateTime.now(),
                    to: DateTime.now().add(const Duration(days: 7)),
                  ),
                  builder: (_, rows) => _thisWeek(rows.take(6).toList()),
                ),
                const SizedBox(height: 24),

                SectionHeader('Upcoming events', onMore: () => widget.onGo(3)),
                Loader<List<Rec>>(
                  key: ValueKey('ev-$_token'),
                  load: () => Data.events(limit: 3),
                  builder: (_, rows) => _upcomingEvents(rows),
                ),
                const SizedBox(height: 24),

                SectionHeader('Recently filed', onMore: () => widget.onGo(4)),
                Loader<List<Rec>>(
                  key: ValueKey('doc-$_token'),
                  load: () => Data.documents(limit: 5),
                  builder: (_, rows) => _recentDocuments(rows),
                ),
                const SizedBox(height: 24),

                SectionHeader(
                  'Current issue',
                  onMore: () => _push(const NewsletterScreen()),
                ),
                Loader<List<Rec>>(
                  key: ValueKey('nl-$_token'),
                  load: () => Data.newsletters(limit: 1),
                  builder: (_, rows) => _currentIssue(rows),
                ),
                const SizedBox(height: 24),

                const SectionHeader('General'),
                InsetGroup(
                  children: [
                    InsetRow(
                      onTap: () => _push(CommitteeScreen(me: me)),
                      child: const _MoreRow(
                        icon: Icons.account_balance_outlined,
                        label: 'Bar Committee',
                      ),
                    ),
                    InsetRow(
                      onTap: () => _push(const CalendarScreen()),
                      child: const _MoreRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Calendar',
                      ),
                    ),
                    InsetRow(
                      onTap: () => _push(const NewsletterScreen()),
                      child: const _MoreRow(
                        icon: Icons.menu_book_outlined,
                        label: 'Newsletter',
                      ),
                    ),
                    InsetRow(
                      onTap: () => _push(SettingsScreen(me: me)),
                      child: const _MoreRow(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _push(Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => screen));

  // ── The day's business ─────────────────────────────────────────────────

  Widget _stats() => Column(
    children: [
      // The first figure is filled, as the web does, so the row has a head
      // rather than four equal voices.
      Row(
        children: [
          Expanded(
            child: Loader<int>(
              key: ValueKey('s1-$_token'),
              load: Data.unreadNotices,
              placeholder: const _StatSkeleton(filled: true),
              builder: (_, n) => _Stat(
                label: 'Unread notices',
                value: n,
                note: 'Not yet opened',
                filled: true,
                onTap: () => widget.onGo(1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Loader<int>(
              key: ValueKey('s2-$_token'),
              load: Data.weekEntries,
              placeholder: const _StatSkeleton(),
              builder: (_, n) => _Stat(
                label: 'This week',
                value: n,
                note: 'Next seven days',
                onTap: () => _push(const CalendarScreen()),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Loader<int>(
              key: ValueKey('s3-$_token'),
              load: Data.openEvents,
              placeholder: const _StatSkeleton(),
              builder: (_, n) => _Stat(
                label: 'Open events',
                value: n,
                note: 'Accepting RSVPs',
                onTap: () => widget.onGo(3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Loader<int>(
              key: ValueKey('s4-$_token'),
              load: Data.membersOnRoll,
              placeholder: const _StatSkeleton(),
              builder: (_, n) => _Stat(
                label: 'Members on roll',
                value: n,
                note: 'Active and life',
                onTap: () => widget.onGo(2),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  // ── Widgets ────────────────────────────────────────────────────────────

  Widget _latestNotices(List<Rec> rows) {
    if (rows.isEmpty) {
      return const EmptyState('No notices have been published yet.');
    }
    return InsetGroup(
      children: [
        for (final a in rows)
          InsetRow(
            onTap: () => _push(
              AnnouncementDetailScreen(id: a['id'] as int, me: widget.me),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (a['pinned'] == true) ...[
                      const Tag('Pinned', tone: Tone.alert),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Tag(
                        categoryLabel[a['category']] ?? humanise(a['category']),
                        tone: a['category'] == 'condolence'
                            ? Tone.neutral
                            : Tone.info,
                      ),
                    ),
                    const Spacer(),
                    Text(day(a['publish_at']), style: T.record),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${a['title']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.headline,
                ),
                if ('${a['body'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${a['body']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.footnote,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _thisWeek(List<Rec> rows) {
    if (rows.isEmpty) {
      return const EmptyState('Nothing listed for the next seven days.');
    }
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _CalendarLine(row: rows[i]),
            if (i != rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _upcomingEvents(List<Rec> rows) {
    if (rows.isEmpty) {
      return const EmptyState('No events are scheduled at present.');
    }
    return InsetGroup(
      children: [
        for (final e in rows)
          InsetRow(
            onTap: () => _push(
              EventDetailScreen(id: e['id'] as int, me: widget.me),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e['title']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.headline,
                ),
                const SizedBox(height: 4),
                Text(
                  '${relativeDay(e['starts_at'])} · ${time(e['starts_at'])}',
                  style: T.record,
                ),
                const SizedBox(height: 8),
                _rsvpBadge(e),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rsvpBadge(Rec e) {
    final mine = (e['event_rsvps'] as List? ?? const [])
        .cast<Rec>()
        .where((r) => r['member_id'] == widget.me.id)
        .toList();

    if (mine.isEmpty) return const Tag('RSVP due', tone: Tone.warn);
    final status = '${mine.first['status']}';
    return Tag(
      switch (status) {
        'attending' => 'Attending',
        'maybe' => 'Maybe',
        _ => 'Not attending',
      },
      tone: status == 'attending' ? Tone.success : Tone.neutral,
    );
  }

  Widget _recentDocuments(List<Rec> rows) {
    if (rows.isEmpty) {
      return const EmptyState('No documents have been filed yet.');
    }
    return InsetGroup(
      children: [
        for (final d in rows)
          InsetRow(
            onTap: () => _push(
              DocumentDetailScreen(id: d['id'] as int, me: widget.me),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: C.ink4,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.callout.copyWith(color: C.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(d['folders'] as Rec?)?['name'] ?? 'Uncategorised'}'
                        ' · ${day(d['created_at'])}',
                        style: T.record,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _currentIssue(List<Rec> rows) {
    if (rows.isEmpty) {
      return const EmptyState('No issue has been published yet.');
    }
    final n = rows.first;
    return AppCard(
      onTap: () => _push(NewsletterDetailScreen(id: n['id'] as int)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The dark board, carrying the dot field rather than the web's
          // yellow sweep.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 96,
              width: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: C.board),
                  const DotField(gap: 6, radius: 1, color: Color(0x1FFFFFFF)),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${n['period'] ?? ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Doto',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xCCFFFFFF),
                            height: 1.2,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: C.accent,
                        ),
                        Text(
                          '${n['issue_no'] ?? ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Doto',
                            fontSize: 9,
                            color: Color(0x8AFFFFFF),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${n['title']}', style: T.headline),
                if ('${n['editorial'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${n['editorial']}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: T.footnote,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A figure from the day's business.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.note,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final int value;
  final String note;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? C.onDark : C.ink;
    final muted = filled ? const Color(0x99FFFFFF) : C.ink4;

    return Material(
      color: filled ? C.ink : C.surface,
      borderRadius: BorderRadius.circular(kRCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRCard),
        child: Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRCard),
            border: Border.all(
              color: filled ? Colors.transparent : C.separator,
              width: 0.5,
            ),
          ),
          child: Stack(
            children: [
              if (filled)
                const Positioned.fill(
                  child: DotField(gap: 8, radius: 1, color: Color(0x1AFFFFFF)),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            label.toUpperCase(),
                            style: T.eyebrow.copyWith(
                              color: muted,
                              fontSize: 11,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_outward_rounded, size: 14, color: muted),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '$value',
                      style: T.figure.copyWith(color: fg, fontSize: 40),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.caption.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton({this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    height: 132,
    decoration: BoxDecoration(
      color: filled ? C.ink : C.surface,
      borderRadius: BorderRadius.circular(kRCard),
      border: Border.all(
        color: filled ? Colors.transparent : C.separator,
        width: 0.5,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: DotField(
      gap: 8,
      radius: 1,
      color: filled ? const Color(0x1AFFFFFF) : C.ink5,
    ),
  );
}

class _CalendarLine extends StatelessWidget {
  const _CalendarLine({required this.row});

  final Rec row;

  @override
  Widget build(BuildContext context) {
    final type = '${row['entry_type']}';
    final s = entryStyle(type);
    final label = (entryTypeLabel[type] ?? 'Other').split(' ').first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: s.bg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: s.border, width: 0.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: s.fg,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row['title']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.callout.copyWith(color: C.ink),
              ),
              const SizedBox(height: 2),
              Text(
                row['all_day'] == true
                    ? relativeDay(row['starts_at'])
                    : '${relativeDay(row['starts_at'])} · ${time(row['starts_at'])}',
                style: T.record,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: C.ink3),
      const SizedBox(width: 12),
      Text(label, style: T.body.copyWith(fontSize: 15)),
    ],
  );
}
