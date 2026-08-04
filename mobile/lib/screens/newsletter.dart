import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';

/// Mirrors src/app/(app)/newsletter — the current issue, then the archive.
class NewsletterScreen extends StatelessWidget {
  const NewsletterScreen({super.key});

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Newsletter',
    child: Loader<List<Rec>>(
      load: Data.newsletters,
      errorMessage: 'Issues could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 4),
      ),
      builder: (context, issues) => ListView(
        padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
        children: [
          const PageHeading(
            'Newsletter',
            eyebrow: 'Association record',
            sub: 'The Gauhati Bar Review — the quarterly journal of the '
                'Association.',
          ),

          if (issues.isEmpty)
            const EmptyState('No issues have been published yet.')
          else ...[
            AppCard(
              padding: const EdgeInsets.all(18),
              onTap: () => _open(context, issues.first),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Cover(
                    period: '${issues.first['period'] ?? ''}',
                    issue: '${issues.first['issue_no'] ?? ''}',
                    large: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT ISSUE', style: T.eyebrow),
                        const SizedBox(height: 8),
                        Text('${issues.first['title']}', style: T.title3),
                        const SizedBox(height: 4),
                        Text(
                          '${issues.first['issue_no']} · '
                          '${issues.first['period'] ?? ''}',
                          style: T.record,
                        ),
                        if ('${issues.first['editorial'] ?? ''}'
                            .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${issues.first['editorial']}',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: T.footnote,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (issues.length > 1) ...[
              const SizedBox(height: 24),
              const SectionHeader('Archive'),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                itemCount: issues.length - 1,
                itemBuilder: (context, i) {
                  final issue = issues[i + 1];
                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => _open(context, issue),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Cover(
                          period: '${issue['period'] ?? ''}',
                          issue: '${issue['issue_no'] ?? ''}',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${issue['period'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.callout.copyWith(color: C.ink),
                        ),
                        const SizedBox(height: 2),
                        Text('${issue['issue_no']}', style: T.record),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    ),
  );

  void _open(BuildContext context, Rec issue) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NewsletterDetailScreen(id: issue['id'] as int),
    ),
  );
}

/// Mirrors src/app/(app)/newsletter/[id].
class NewsletterDetailScreen extends StatelessWidget {
  const NewsletterDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Issue',
    child: Loader<Rec?>(
      load: () => Data.newsletter(id),
      errorMessage: 'This issue could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 5),
      ),
      builder: (context, i) {
        if (i == null) {
          return const Padding(
            padding: EdgeInsets.all(kGutter),
            child: EmptyState('This issue is no longer available.'),
          );
        }

        final pdf = i['pdf_path'] as String?;

        return ListView(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i['issue_no']}'.toUpperCase(), style: T.eyebrow),
                  const SizedBox(height: 10),
                  Text('${i['title']}', style: T.title1),
                  const SizedBox(height: 6),
                  Text(
                    '${i['period'] ?? ''}'
                    '${i['published_at'] != null ? ' · published ${day(i['published_at'])}' : ''}',
                    style: T.record,
                  ),

                  if ('${i['editorial'] ?? ''}'.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Divider(height: 0.5, color: C.separator),
                    ),
                    const Text('EDITORIAL NOTE', style: T.eyebrow),
                    const SizedBox(height: 10),
                    Text(
                      '${i['editorial']}',
                      style: T.body.copyWith(
                        fontSize: 15,
                        height: 1.65,
                        color: C.ink2,
                      ),
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(height: 0.5, color: C.separator),
                  ),

                  // The reader is still to come on the web too — say so plainly
                  // rather than showing an empty frame.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kRControl),
                    child: DotField(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 34,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(kRControl),
                          border: Border.all(color: C.separator, width: 0.5),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 30,
                              color: C.ink4,
                            ),
                            const SizedBox(height: 12),
                            if (pdf != null && pdf.isNotEmpty) ...[
                              Text(
                                pdf.split('/').last,
                                textAlign: TextAlign.center,
                                style: T.footnote.copyWith(color: C.ink2),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              'The issue reader appears here once the PDF is '
                              'uploaded to storage.',
                              textAlign: TextAlign.center,
                              style: T.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (i['document_id'] != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Also filed in the Newsletter Archive of the document '
                      'library.',
                      style: T.caption,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionHeader('Call for contributions'),
            AppCard(
              child: Text(
                'Members are invited to submit articles, case notes and '
                'reflections for the next issue. Submissions are reviewed by '
                'the Editorial Committee.',
                style: T.footnote,
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The issue cover: the dark board carrying the dot field and the masthead.
class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.period,
    required this.issue,
    this.large = false,
  });

  final String period;
  final String issue;
  final bool large;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      height: large ? 168 : 124,
      width: large ? 122 : 90,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: C.board),
          const DotField(gap: 6, radius: 1, color: Color(0x1FFFFFFF)),
          Padding(
            padding: EdgeInsets.all(large ? 12 : 9),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GHCBA',
                  style: TextStyle(
                    fontFamily: 'Doto',
                    fontSize: large ? 11 : 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0x80FFFFFF),
                    letterSpacing: 1.4,
                    height: 1,
                  ),
                ),
                SizedBox(height: large ? 10 : 7),
                Text(
                  'The Gauhati Bar Review',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: large ? 13 : 10,
                    fontWeight: FontWeight.w600,
                    color: C.onDark,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                Container(
                  width: large ? 34 : 24,
                  height: 1,
                  margin: EdgeInsets.symmetric(vertical: large ? 10 : 7),
                  color: C.accent,
                ),
                Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Doto',
                    fontSize: large ? 11 : 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xB3FFFFFF),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  issue,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Doto',
                    fontSize: large ? 9 : 8,
                    color: const Color(0x66FFFFFF),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
