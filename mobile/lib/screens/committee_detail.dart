import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'document_detail.dart';
import 'member_detail.dart';

/// Mirrors src/app/(app)/committee/[id] — terms of reference, the members, and
/// whatever minutes or reports have been linked to the committee.
class CommitteeDetailScreen extends StatelessWidget {
  const CommitteeDetailScreen({super.key, required this.id, this.me});

  final int id;
  final Me? me;

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Committee',
    child: Loader<List<Object?>>(
      load: () =>
          Future.wait([Data.committee(id), Data.committeeDocuments(id)]),
      errorMessage: 'This committee could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 5),
      ),
      builder: (context, results) {
        final c = results[0] as Rec?;
        if (c == null) {
          return const Padding(
            padding: EdgeInsets.all(kGutter),
            child: EmptyState('This committee is no longer on record.'),
          );
        }

        final docs = (results[1] as List).cast<Rec>();
        final term = c['committee_terms'] as Rec?;
        final people = ((c['committee_members'] as List?) ?? const [])
            .cast<Rec>()
            .toList()
          ..sort(
            (a, b) => ((a['sort'] as num?) ?? 0).compareTo(
              (b['sort'] as num?) ?? 0,
            ),
          );

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
                    children: [
                      if (term != null)
                        Tag('${term['label']}', tone: Tone.info),
                      Tag(
                        c['kind'] == 'sub'
                            ? 'Sub-committee'
                            : 'Standing committee',
                      ),
                      if (term != null && term['is_current'] != true)
                        const Tag('Archived', tone: Tone.warn),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('${c['name']}', style: T.title2),

                  if ('${c['mandate'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('TERMS OF REFERENCE', style: T.eyebrow),
                    const SizedBox(height: 9),
                    Text(
                      '${c['mandate']}',
                      style: T.body.copyWith(
                        fontSize: 15,
                        height: 1.6,
                        color: C.ink2,
                      ),
                    ),
                  ],

                  if (c['formed_on'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Constituted on ${day(c['formed_on'])}.',
                      style: T.caption,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            SectionHeader('Members (${people.length})'),
            if (people.isEmpty)
              const EmptyState('No members recorded.')
            else
              InsetGroup(
                children: [
                  for (final p in people)
                    InsetRow(
                      onTap: me == null || (p['members'] as Rec?) == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MemberDetailScreen(
                                  id: '${(p['members'] as Rec)['id']}',
                                  me: me!,
                                ),
                              ),
                            ),
                      child: Row(
                        children: [
                          Avatar(
                            name: '${(p['members'] as Rec?)?['full_name'] ?? ''}',
                            url: (p['members'] as Rec?)?['photo_url'] as String?,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(p['members'] as Rec?)?['full_name'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.headline.copyWith(fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${p['designation'] ?? ''}',
                                  style: T.record,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 20),
            const SectionHeader('Associated documents'),
            if (docs.isEmpty)
              const EmptyState(
                'No minutes or reports have been linked to this committee.',
              )
            else
              InsetGroup(
                children: [
                  for (final d in docs)
                    if ((d['documents'] as Rec?) != null)
                      InsetRow(
                        onTap: me == null
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DocumentDetailScreen(
                                    id: (d['documents'] as Rec)['id'] as int,
                                    me: me!,
                                  ),
                                ),
                              ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 17,
                              color: C.ink4,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${(d['documents'] as Rec)['title']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.callout.copyWith(color: C.ink),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              day((d['documents'] as Rec)['created_at']),
                              style: T.record,
                            ),
                          ],
                        ),
                      ),
                ],
              ),
          ],
        );
      },
    ),
  );
}
