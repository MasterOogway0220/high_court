import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'announcements.dart' show FilterPill;
import 'events.dart' show SegmentedTabs;

/// Mirrors src/app/(app)/calendar. PRD 3.4 puts the list first on mobile and
/// keeps the month grid reachable, so that is the order here.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _grid = false;
  String? _type;
  DateTime _cursor = DateTime.now();
  DateTime? _selected;
  int _token = 0;

  DateTime get _from => _grid
      ? _gridStart
      : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  DateTime get _to =>
      _grid ? _gridEnd : DateTime(_cursor.year, _cursor.month + 6, _cursor.day);

  DateTime get _monthStart => DateTime(_cursor.year, _cursor.month);
  DateTime get _monthEnd => DateTime(_cursor.year, _cursor.month + 1, 0);

  /// The grid runs Monday-first, as the web sets weekStartsOn: 1.
  DateTime get _gridStart =>
      _monthStart.subtract(Duration(days: _monthStart.weekday - 1));

  DateTime get _gridEnd =>
      _monthEnd.add(Duration(days: 7 - _monthEnd.weekday));

  void _shiftMonth(int by) => setState(() {
    _cursor = DateTime(_cursor.year, _cursor.month + by);
    _selected = null;
    _token++;
  });

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Calendar',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
      children: [
        const PageHeading(
          'Calendar',
          eyebrow: 'Association record',
          sub: 'Court holidays, meetings, events and elections.',
        ),

        SegmentedTabs(
          labels: const ['List', 'Month'],
          index: _grid ? 1 : 0,
          onChanged: (i) => setState(() {
            _grid = i == 1;
            _selected = null;
            _token++;
          }),
        ),
        const SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 7,
            children: [
              FilterPill(
                label: 'All types',
                selected: _type == null,
                onTap: () => setState(() {
                  _type = null;
                  _token++;
                }),
              ),
              for (final e in entryTypeLabel.entries)
                FilterPill(
                  label: e.value,
                  selected: _type == e.key,
                  onTap: () => setState(() {
                    _type = e.key;
                    _token++;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_grid) ...[
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Text(
                  monthYear(_cursor),
                  textAlign: TextAlign.center,
                  style: T.title3,
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        Loader<List<Rec>>(
          key: ValueKey('$_grid-$_type-$_token-${_cursor.month}-${_cursor.year}'),
          load: () => Data.calendar(from: _from, to: _to, type: _type),
          errorMessage: 'The calendar could not be loaded.',
          placeholder: const SkeletonCard(lines: 5),
          builder: (context, rows) =>
              _grid ? _month(rows) : _list(rows),
        ),

        const SizedBox(height: 20),
        const SectionHeader('Legend'),
        AppCard(
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final e in entryTypeLabel.entries)
                EntryTag(type: e.key, label: e.value),
            ],
          ),
        ),

        const SizedBox(height: 16),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.rss_feed_rounded, size: 18, color: C.ink4),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscribe in your phone calendar',
                      style: T.callout.copyWith(color: C.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Generate a personal feed link from Settings, then add it '
                      'in Google or Apple Calendar.',
                      style: T.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── List ────────────────────────────────────────────────────────────────

  Widget _list(List<Rec> rows) {
    if (rows.isEmpty) {
      return const EmptyState('No calendar entries in this period.');
    }
    return Column(
      children: [
        for (final e in rows) ...[
          _EntryCard(row: e),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  // ── Month grid ──────────────────────────────────────────────────────────

  Widget _month(List<Rec> rows) {
    final days = <DateTime>[];
    for (
      var d = _gridStart;
      !d.isAfter(_gridEnd);
      d = d.add(const Duration(days: 1))
    ) {
      days.add(d);
    }

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    List<Rec> on(DateTime d) =>
        rows.where((e) => sameDay(at(e['starts_at']), d)).toList();

    final today = DateTime.now();
    final selected = _selected;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(kRCard),
            border: Border.all(color: C.separator, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                color: C.canvas,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    for (final d in const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ])
                      Expanded(
                        child: Text(
                          d.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: T.eyebrow.copyWith(
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.86,
                    ),
                itemCount: days.length,
                itemBuilder: (context, i) {
                  final d = days[i];
                  final entries = on(d);
                  final inMonth = d.month == _cursor.month;
                  final isToday = sameDay(d, today);
                  final isSelected = selected != null && sameDay(d, selected);

                  return GestureDetector(
                    onTap: entries.isEmpty
                        ? null
                        : () => setState(() => _selected = d),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? C.sunk : null,
                        border: const Border(
                          right: BorderSide(color: C.separator, width: 0.5),
                          bottom: BorderSide(color: C.separator, width: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 24,
                            width: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday ? C.ink : null,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                fontFamily: 'Doto',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                color: isToday
                                    ? C.onDark
                                    : inMonth
                                    ? C.ink2
                                    : C.ink5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final e in entries.take(3))
                                Container(
                                  height: 4,
                                  width: 4,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: entryStyle(
                                      '${e['entry_type']}',
                                    ).bg == C.surface
                                        ? C.ink3
                                        : entryStyle('${e['entry_type']}').bg,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tapping a day narrows the list below it; with nothing chosen the
        // whole month is listed, so the grid never becomes a dead end.
        ...() {
          final shown = selected == null ? rows : on(selected);
          if (shown.isEmpty) {
            return [
              const EmptyState('No calendar entries in this period.'),
            ];
          }
          return [
            if (selected != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(day(selected), style: T.eyebrow),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selected = null),
                      child: Text(
                        'Show whole month',
                        style: T.footnote.copyWith(
                          color: C.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final e in shown) ...[
              _EntryCard(row: e),
              const SizedBox(height: 10),
            ],
          ];
        }(),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.row});

  final Rec row;

  @override
  Widget build(BuildContext context) {
    final starts = at(row['starts_at']);
    final type = '${row['entry_type']}';

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  monthAbbrev(starts).toUpperCase(),
                  style: T.eyebrow.copyWith(fontSize: 10, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text('${starts.day}', style: T.figure.copyWith(fontSize: 26)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntryTag(
                  type: type,
                  label: entryTypeLabel[type] ?? 'Other',
                ),
                const SizedBox(height: 8),
                Text('${row['title']}', style: T.headline.copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  row['all_day'] == true
                      ? day(row['starts_at'])
                      : '${day(row['starts_at'])} · ${time(row['starts_at'])}',
                  style: T.record,
                ),
                if ('${row['description'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${row['description']}',
                    maxLines: 2,
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

/// A calendar entry type, in the treatment that separates it from the others
/// without leaving the monochrome palette.
class EntryTag extends StatelessWidget {
  const EntryTag({super.key, required this.type, required this.label});

  final String type;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = entryStyle(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: s.border, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: s.fg,
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: C.separator, width: 0.5),
      ),
      child: Icon(icon, size: 20, color: C.ink2),
    ),
  );
}
