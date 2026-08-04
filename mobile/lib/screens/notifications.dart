import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';

/// Mirrors src/app/(app)/notifications — the in-app notification centre with
/// read/unread state (PRD 4.2).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.me});

  final Me me;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _token = 0;
  bool _marking = false;

  Future<void> _markAll() async {
    setState(() => _marking = true);
    try {
      await Data.markAllNotificationsRead(widget.me.id);
    } finally {
      if (mounted) {
        setState(() {
          _marking = false;
          _token++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Notifications',
    child: Loader<List<Rec>>(
      key: ValueKey(_token),
      load: Data.notifications,
      errorMessage: 'Notifications could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 4),
      ),
      builder: (context, rows) {
        final unread = rows.where((n) => n['read_at'] == null).length;

        return RefreshIndicator(
          onRefresh: () async => setState(() => _token++),
          color: C.ink,
          backgroundColor: C.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
            children: [
              PageHeading(
                'Notifications',
                sub: 'Notices, event reminders and updates on your enquiries.',
                aside: unread > 0
                    ? SizedBox(
                        height: 34,
                        child: AppButton(
                          'Mark all read',
                          variant: BtnVariant.outline,
                          busy: _marking,
                          onPressed: _markAll,
                        ),
                      )
                    : null,
              ),

              if (rows.isEmpty)
                const EmptyState('You have no notifications.')
              else
                InsetGroup(
                  children: [
                    for (final n in rows)
                      InsetRow(
                        chevron: false,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6, right: 10),
                              height: 7,
                              width: 7,
                              decoration: BoxDecoration(
                                color: n['read_at'] == null
                                    ? C.accent
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${n['title']}',
                                    style: T.headline.copyWith(
                                      fontSize: 15,
                                      fontWeight: n['read_at'] == null
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: n['read_at'] == null
                                          ? C.ink
                                          : C.ink2,
                                    ),
                                  ),
                                  if ('${n['body'] ?? ''}'.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text('${n['body']}', style: T.footnote),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Tag(humanise('${n['kind']}')),
                                      const SizedBox(width: 8),
                                      Text(ago(n['created_at']), style: T.record),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    ),
  );
}
