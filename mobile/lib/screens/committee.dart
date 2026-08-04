import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'committee_detail.dart';
import 'member_detail.dart';

/// Mirrors src/app/(app)/committee — office bearers, the Executive Committee,
/// then the standing and sub-committees of the current term.
class CommitteeScreen extends StatelessWidget {
  const CommitteeScreen({super.key, this.me});

  final Me? me;

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Bar Committee',
    child: Loader<List<Object?>>(
      load: () async {
        final terms = await Data.committeeTerms();
        final currentList = terms.where((t) => t['is_current'] == true).toList();
        final term = currentList.isNotEmpty
            ? currentList.first
            : (terms.isEmpty ? null : terms.first);
        if (term == null) return [null, <Rec>[]];
        return [term, await Data.committees(term['id'] as int)];
      },
      errorMessage: 'The committee could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 5),
      ),
      builder: (context, results) {
        final term = results[0] as Rec?;
        final committees = (results[1] as List).cast<Rec>();

        List<Rec> byKind(String k) =>
            committees.where((c) => c['kind'] == k).toList();

        final officeBearers = byKind('office_bearers');
        final executive = byKind('executive');
        final standing = [...byKind('standing'), ...byKind('sub')];

        List<Rec> sorted(Rec? c) {
          final list = ((c?['committee_members'] as List?) ?? const [])
              .cast<Rec>()
              .toList()
            ..sort(
              (a, b) => ((a['sort'] as num?) ?? 0).compareTo(
                (b['sort'] as num?) ?? 0,
              ),
            );
          return list;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
          children: [
            const PageHeading(
              'Bar Committee',
              sub: 'Office bearers, the Executive Committee, and the standing '
                  'and sub-committees of the Association.',
            ),

            if (term != null && term['is_current'] != true) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Tag('Archived term — read only', tone: Tone.warn),
              ),
            ],

            if (committees.isEmpty)
              const EmptyState('No committees are recorded for this term.')
            else ...[
              if (officeBearers.isNotEmpty) ...[
                const SectionHeader('Office bearers'),
                ...() {
                  final people = sorted(officeBearers.first);
                  if (people.isEmpty) {
                    return [const EmptyState('No office bearers recorded.')];
                  }
                  final president = people.first;
                  final others = people.skip(1).toList();
                  return [
                    _PresidentCard(row: president, me: me),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _PeopleGrid(people: others, me: me),
                    ],
                  ];
                }(),
                const SizedBox(height: 24),
              ],

              if (executive.isNotEmpty) ...[
                const SectionHeader('Executive Committee'),
                _PeopleGrid(people: sorted(executive.first), me: me),
                const SizedBox(height: 24),
              ],

              if (standing.isNotEmpty) ...[
                const SectionHeader('Standing & sub-committees'),
                InsetGroup(
                  children: [
                    for (final c in standing)
                      InsetRow(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommitteeDetailScreen(
                              id: c['id'] as int,
                              me: me,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${c['name']}',
                                    style: T.headline.copyWith(fontSize: 15),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tag(c['kind'] == 'sub' ? 'Sub' : 'Standing'),
                              ],
                            ),
                            if ('${c['mandate'] ?? ''}'.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${c['mandate']}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: T.footnote,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              [
                                if ((c['members'] as Rec?) != null)
                                  'Convenor: ${(c['members'] as Rec)['full_name']}',
                                '${((c['committee_members'] as List?) ?? const []).length} members',
                                if (c['formed_on'] != null)
                                  'Formed ${day(c['formed_on'])}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.record,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ],
        );
      },
    ),
  );
}

class _PresidentCard extends StatelessWidget {
  const _PresidentCard({required this.row, this.me});

  final Rec row;
  final Me? me;

  @override
  Widget build(BuildContext context) {
    final m = row['members'] as Rec?;
    if (m == null) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: me == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemberDetailScreen(id: '${m['id']}', me: me!),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            name: '${m['full_name']}',
            url: m['photo_url'] as String?,
            size: 66,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['designation'] ?? ''}'.toUpperCase(),
                  style: T.eyebrow.copyWith(color: C.ink),
                ),
                const SizedBox(height: 7),
                Text('${m['full_name']}', style: T.title3),
                const SizedBox(height: 3),
                Text('${m['enrolment_no'] ?? ''}', style: T.record),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleGrid extends StatelessWidget {
  const _PeopleGrid({required this.people, this.me});

  final List<Rec> people;
  final Me? me;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const EmptyState('No members recorded.');

    return InsetGroup(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}
