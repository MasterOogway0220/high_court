import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'member_detail.dart';

/// Mirrors src/app/(app)/events/[id] — the event, the attendee list where the
/// organiser has opened it, and the member's own RSVP (PRD 3.5).
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.id, required this.me});

  final int id;
  final Me me;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  int _token = 0;

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Event',
    child: Loader<List<Object?>>(
      key: ValueKey(_token),
      load: () =>
          Future.wait([Data.event(widget.id), Data.eventRsvps(widget.id)]),
      errorMessage: 'This event could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 6),
      ),
      builder: (context, results) {
        final e = results[0] as Rec?;
        if (e == null) {
          return const Padding(
            padding: EdgeInsets.all(kGutter),
            child: EmptyState('This event is no longer available.'),
          );
        }

        final rsvps = (results[1] as List).cast<Rec>();
        final mineList = rsvps
            .where((r) => r['member_id'] == widget.me.id)
            .toList();
        final mine = mineList.isEmpty ? null : mineList.first;
        final going = rsvps
            .where((r) => r['status'] == 'attending' && r['waitlisted'] != true)
            .toList();
        final waiting = rsvps.where((r) => r['waitlisted'] == true).toList();
        final seats = going.fold<int>(
          0,
          (n, r) => n + 1 + ((r['guests'] as num?)?.toInt() ?? 0),
        );

        final starts = at(e['starts_at']);
        final past = starts.isBefore(DateTime.now());
        final deadline = e['rsvp_deadline'];
        final closed =
            past ||
            (deadline != null && at(deadline).isBefore(DateTime.now()));
        final canSeeList =
            e['show_attendees'] == true ||
            e['organiser_id'] == widget.me.id ||
            widget.me.canPublish;
        final capacity = (e['capacity'] as num?)?.toInt();
        final organiser = e['members'] as Rec?;

        return ListView(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The dark board, carrying the dot field.
                  SizedBox(
                    height: 104,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: C.board),
                        const DotField(
                          gap: 7,
                          radius: 1,
                          color: Color(0x1FFFFFFF),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
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
                                eventTypeLabel[e['event_type']] ??
                                    humanise(e['event_type']),
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
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e['title']}', style: T.title2),
                        const SizedBox(height: 14),
                        _Fact(
                          icon: Icons.calendar_today_rounded,
                          text:
                              '${day(e['starts_at'])} · ${time(e['starts_at'])}'
                              '${e['ends_at'] != null ? '–${time(e['ends_at'])}' : ''}',
                        ),
                        if ('${e['venue'] ?? ''}'.isNotEmpty)
                          _Fact(
                            icon: Icons.place_outlined,
                            text: '${e['venue']}',
                          ),
                        if (organiser != null)
                          _Fact(
                            icon: Icons.person_outline_rounded,
                            text: 'Organised by ${organiser['full_name']}',
                          ),
                        _Fact(
                          icon: Icons.groups_outlined,
                          text:
                              '$seats attending${capacity != null ? ' of $capacity' : ''}',
                        ),
                        if ('${e['description'] ?? ''}'.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 0.5, color: C.separator),
                          ),
                          Text(
                            '${e['description']}',
                            style: T.body.copyWith(
                              fontSize: 15,
                              height: 1.6,
                              color: C.ink2,
                            ),
                          ),
                        ],
                        if ('${e['outcome_note'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: C.canvas,
                              borderRadius: BorderRadius.circular(kRControl),
                              border: Border.all(
                                color: C.separator,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('OUTCOME', style: T.eyebrow),
                                const SizedBox(height: 8),
                                Text(
                                  '${e['outcome_note']}',
                                  style: T.footnote.copyWith(color: C.ink2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionHeader('Your RSVP'),
            _RsvpPanel(
              eventId: widget.id,
              initialStatus: mine?['status'] as String?,
              initialGuests: (mine?['guests'] as num?)?.toInt() ?? 0,
              initialWaitlisted: mine?['waitlisted'] == true,
              allowGuests: e['allow_guests'] == true,
              closed: closed,
              deadline: deadline,
              onChanged: () => setState(() => _token++),
            ),

            if (capacity != null) ...[
              const SizedBox(height: 20),
              const SectionHeader('Capacity'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: capacity == 0
                            ? 0
                            : (seats / capacity).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: C.sunk,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$seats of $capacity places taken'
                      '${waiting.isNotEmpty ? ' · ${waiting.length} waiting' : ''}',
                      style: T.footnote,
                    ),
                  ],
                ),
              ),
            ],

            if (canSeeList) ...[
              const SizedBox(height: 20),
              SectionHeader('Attendees (${going.length})'),
              if (going.isEmpty)
                const EmptyState('No one has confirmed yet.')
              else
                InsetGroup(
                  children: [
                    for (final r in going)
                      InsetRow(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemberDetailScreen(
                              id: '${r['member_id']}',
                              me: widget.me,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Avatar(
                              name: '${(r['members'] as Rec?)?['full_name'] ?? ''}',
                              url: (r['members'] as Rec?)?['photo_url'] as String?,
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${(r['members'] as Rec?)?['full_name'] ?? 'Member'}'
                                '${((r['guests'] as num?)?.toInt() ?? 0) > 0 ? ' +${r['guests']}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.callout.copyWith(color: C.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (waiting.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${waiting.length} on the waitlist.',
                  style: T.caption,
                ),
              ],
            ],
          ],
        );
      },
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: C.ink4),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: T.footnote.copyWith(color: C.ink2))),
      ],
    ),
  );
}

/// PRD 3.5: the choice applies at once and reconciles against what the RPC
/// actually recorded — capacity may have turned an "attending" into a waitlist.
class _RsvpPanel extends StatefulWidget {
  const _RsvpPanel({
    required this.eventId,
    required this.initialStatus,
    required this.initialGuests,
    required this.initialWaitlisted,
    required this.allowGuests,
    required this.closed,
    required this.deadline,
    required this.onChanged,
  });

  final int eventId;
  final String? initialStatus;
  final int initialGuests;
  final bool initialWaitlisted;
  final bool allowGuests;
  final bool closed;
  final dynamic deadline;
  final VoidCallback onChanged;

  @override
  State<_RsvpPanel> createState() => _RsvpPanelState();
}

class _RsvpPanelState extends State<_RsvpPanel> {
  late String? _status = widget.initialStatus;
  late int _guests = widget.initialGuests;
  late bool _waitlisted = widget.initialWaitlisted;
  bool _busy = false;
  String? _error;

  static const _choices = [
    ('attending', 'Attending'),
    ('maybe', 'Maybe'),
    ('not_attending', 'Not attending'),
  ];

  Future<void> _choose(String status, {int? guests}) async {
    final previous = (_status, _guests, _waitlisted);
    setState(() {
      _busy = true;
      _error = null;
      _status = status;
      if (guests != null) _guests = guests;
      _waitlisted = false;
    });

    try {
      final row = await Data.setRsvp(
        widget.eventId,
        status,
        status == 'attending' ? _guests : 0,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = (row?['status'] as String?) ?? status;
        _waitlisted = row?['waitlisted'] == true;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      // The optimistic state was a guess and it was wrong — put it back.
      setState(() {
        _busy = false;
        _status = previous.$1;
        _guests = previous.$2;
        _waitlisted = previous.$3;
        _error = 'That RSVP could not be recorded. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.closed) {
      return AppCard(
        child: Text('RSVP for this event has closed.', style: T.footnote),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < _choices.length; i++) ...[
                Expanded(
                  child: _RsvpButton(
                    label: _choices[i].$2,
                    selected: _status == _choices[i].$1,
                    enabled: !_busy,
                    onTap: () => _choose(_choices[i].$1),
                  ),
                ),
                if (i != _choices.length - 1) const SizedBox(width: 7),
              ],
            ],
          ),

          if (widget.allowGuests && _status == 'attending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Accompanying persons',
                    style: T.footnote.copyWith(color: C.ink2),
                  ),
                ),
                for (final n in [0, 1, 2, 3, 4])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _GuestChip(
                      n: n,
                      selected: _guests == n,
                      onTap: _busy
                          ? null
                          : () => _choose('attending', guests: n),
                    ),
                  ),
              ],
            ),
          ],

          if (_waitlisted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.canvas,
                borderRadius: BorderRadius.circular(kRControl),
                border: Border.all(color: C.ink, width: 0.5),
              ),
              child: Text(
                'This event is full — you are on the waitlist and will be '
                'confirmed automatically if a place opens.',
                style: T.footnote.copyWith(color: C.ink2),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: T.footnote.copyWith(
                color: C.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          if (widget.deadline != null) ...[
            const SizedBox(height: 12),
            Text(
              'You may change this until ${dayTime(widget.deadline)}.',
              style: T.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? C.ink : C.surface,
    borderRadius: BorderRadius.circular(kRControl),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(kRControl),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRControl),
          border: Border.all(
            color: selected ? C.ink : C.separator,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? C.onDark : C.ink2,
          ),
        ),
      ),
    ),
  );
}

class _GuestChip extends StatelessWidget {
  const _GuestChip({
    required this.n,
    required this.selected,
    required this.onTap,
  });

  final int n;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 30,
      width: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? C.ink : C.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? C.ink : C.separator, width: 0.5),
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontFamily: 'Doto',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: selected ? C.onDark : C.ink3,
          height: 1,
        ),
      ),
    ),
  );
}
