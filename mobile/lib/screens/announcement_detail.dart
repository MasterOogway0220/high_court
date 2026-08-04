import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';

/// Mirrors src/app/(app)/announcements/[id] — the notice in full, with a read
/// receipt written on open (PRD 3.3).
class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.id,
    required this.me,
  });

  final int id;
  final Me me;

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Notice',
    child: Loader<Rec?>(
      load: () async {
        final row = await Data.announcement(id);
        // Idempotent, and aggregate-only in reporting — the office sees a count,
        // never who read what.
        if (row != null) await Data.markRead(id, me.id);
        return row;
      },
      errorMessage: 'This notice could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 6),
      ),
      builder: (context, a) {
        if (a == null) {
          return const Padding(
            padding: EdgeInsets.all(kGutter),
            child: EmptyState('This notice is no longer available.'),
          );
        }

        final condolence = a['category'] == 'condolence';
        final priority = '${a['priority']}';
        final author = a['members'] as Rec?;
        final files = (a['announcement_attachments'] as List? ?? const [])
            .cast<Rec>();

        return ListView(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (a['pinned'] == true)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              size: 11,
                              color: C.accent,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: C.accent,
                              ),
                            ),
                          ],
                        ),
                      Tag(
                        categoryLabel[a['category']] ??
                            humanise(a['category']),
                        tone: condolence ? Tone.neutral : Tone.info,
                      ),
                      if (priority != 'normal' && !condolence)
                        Tag(
                          humanise(priority),
                          tone: priority == 'urgent' ? Tone.alert : Tone.warn,
                        ),
                      if (a['visibility'] != 'all_members')
                        Tag(
                          visibilityLabel[a['visibility']] ??
                              humanise(a['visibility']),
                          tone: Tone.warn,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${a['title']}',
                    style: T.title1.copyWith(
                      color: condolence ? C.ink2 : C.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayTime(a['publish_at']) +
                        (author != null
                            ? ' · issued by ${author['full_name']}'
                            : ''),
                    style: T.record,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(height: 0.5, color: C.separator),
                  ),
                  // A generous measure — notices are read, not scanned (PRD 5.3).
                  SelectableText(
                    '${a['body'] ?? ''}',
                    style: T.body.copyWith(height: 1.7, color: C.ink2),
                  ),
                  if (a['expires_at'] != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'This notice expires on ${dayTime(a['expires_at'])}.',
                      style: T.caption,
                    ),
                  ],
                ],
              ),
            ),

            if (files.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader('Attachments'),
              InsetGroup(
                children: [
                  for (final f in files)
                    InsetRow(
                      chevron: false,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 16,
                            color: C.ink4,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${f['file_name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.callout.copyWith(color: C.ink),
                            ),
                          ),
                          Text(fileSize(f['size_bytes']), style: T.record),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );
}
