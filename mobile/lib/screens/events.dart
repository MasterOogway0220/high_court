import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'chrome.dart';
import 'event_detail.dart';

/// Mirrors src/app/(app)/events — upcoming by default, with the archive behind
/// the second tab.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.me});

  final Me me;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _past = false;
  int _token = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppHeader(me: widget.me),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => setState(() => _token++),
          color: C.ink,
          backgroundColor: C.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 32),
            children: [
              const PageHeading(
                'Events',
                eyebrow: 'Association record',
                sub: 'Seminars, training, meetings and gatherings of the '
                    'Association.',
              ),

              SegmentedTabs(
                labels: const ['Upcoming', 'Archive'],
                index: _past ? 1 : 0,
                onChanged: (i) => setState(() {
                  _past = i == 1;
                  _token++;
                }),
              ),
              const SizedBox(height: 16),

              Loader<List<Rec>>(
                key: ValueKey('$_past-$_token'),
                load: () => Data.events(past: _past),
                errorMessage: 'Events could not be loaded.',
                placeholder: const Column(
                  children: [
                    SkeletonCard(),
                    SizedBox(height: 10),
                    SkeletonCard(),
                  ],
                ),
                builder: (context, rows) => rows.isEmpty
                    ? EmptyState(
                        _past
                            ? 'No past events on record.'
                            : 'No events are scheduled at present.',
                      )
                    : Column(
                        children: [
                          for (final e in rows) ...[
                            _EventCard(
                              row: e,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(
                                    id: e['id'] as int,
                                    me: widget.me,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.row, required this.onTap});

  final Rec row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rsvps = (row['event_rsvps'] as List? ?? const []).cast<Rec>();
    final going = rsvps.where(
      (r) => r['status'] == 'attending' && r['waitlisted'] != true,
    );
    final seats = going.fold<int>(
      0,
      (n, r) => n + 1 + ((r['guests'] as num?)?.toInt() ?? 0),
    );
    final capacity = (row['capacity'] as num?)?.toInt();

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 76,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: C.board),
                const DotField(gap: 7, radius: 1, color: Color(0x1FFFFFFF)),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        eventTypeLabel[row['event_type']] ??
                            humanise(row['event_type']),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: C.onDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day(row['starts_at'])} · ${time(row['starts_at'])}',
                  style: T.record.copyWith(color: C.ink2),
                ),
                const SizedBox(height: 6),
                Text('${row['title']}', style: T.title3),
                if ('${row['description'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${row['description']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.footnote,
                  ),
                ],
                const SizedBox(height: 12),
                if ('${row['venue'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: C.ink4,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${row['venue']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const Icon(Icons.groups_outlined, size: 13, color: C.ink4),
                    const SizedBox(width: 6),
                    Text(
                      '$seats attending${capacity != null ? ' of $capacity' : ''}',
                      style: T.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An iOS-style segmented control — the app's stand-in for the web's tab rail.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: C.sunk,
      borderRadius: BorderRadius.circular(kRControl),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == index ? C.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == index ? C.separator : Colors.transparent,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: i == index
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: i == index ? C.ink : C.ink3,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
