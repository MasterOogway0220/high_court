import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'committee_detail.dart';

/// Mirrors src/app/(app)/directory/[id] — the member's record, with contact
/// details gated by their own privacy toggles (PRD 3.2).
class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.id, required this.me});

  final String id;
  final Me me;

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Member',
    child: Loader<List<Object?>>(
      load: () => Future.wait([Data.member(id), Data.memberPositions(id)]),
      errorMessage: 'This member record could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 5),
      ),
      builder: (context, results) {
        final m = results[0] as Rec?;
        if (m == null) {
          return const Padding(
            padding: EdgeInsets.all(kGutter),
            child: EmptyState('This member is not on the roll.'),
          );
        }

        final positions = (results[1] as List).cast<Rec>();
        final live = const {
          'active',
          'life',
        }.contains(m['membership_status']);

        // Office bearers always see the full record; so does the member.
        final full = me.canPublish || me.id == m['id'];
        final showMobile = full || m['hide_mobile'] != true;
        final showEmail = full || m['hide_email'] != true;

        bool isCurrent(Rec p) =>
            ((p['committees'] as Rec?)?['committee_terms']
                as Rec?)?['is_current'] ==
            true;
        final current = positions.where(isCurrent).toList();
        final past = positions.where((p) => !isCurrent(p)).toList();

        final areas = (m['practice_areas'] as List? ?? const [])
            .cast<String>();

        return ListView(
          padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(
                        name: '${m['full_name']}',
                        url: m['photo_url'] as String?,
                        size: 68,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m['full_name']}', style: T.title2),
                            const SizedBox(height: 4),
                            Text(
                              designationLabel[m['designation']] ??
                                  humanise(m['designation']),
                              style: T.footnote.copyWith(color: C.ink2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Tag('${m['enrolment_no']}', tone: Tone.info),
                      Tag(
                        humanise(m['membership_status']),
                        tone: live ? Tone.success : Tone.warn,
                      ),
                      if (m['enrolment_date'] != null)
                        Tag('Enrolled ${day(m['enrolment_date'])}'),
                    ],
                  ),

                  if (areas.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text('PRACTICE AREAS', style: T.eyebrow),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final a in areas) Tag(a)],
                    ),
                  ],

                  if ('${m['bio'] ?? ''}'.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Divider(height: 0.5, color: C.separator),
                    ),
                    Text(
                      '${m['bio']}',
                      style: T.body.copyWith(fontSize: 15, color: C.ink2),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionHeader('Contact'),
            InsetGroup(
              children: [
                if ('${m['chamber_address'] ?? ''}'.isNotEmpty)
                  InsetRow(
                    chevron: false,
                    child: _ContactLine(
                      icon: Icons.place_outlined,
                      value: '${m['chamber_address']}',
                    ),
                  ),
                if ('${m['chamber_phone'] ?? ''}'.isNotEmpty)
                  InsetRow(
                    chevron: false,
                    onTap: () => _dial('${m['chamber_phone']}'),
                    child: _ContactLine(
                      icon: Icons.business_outlined,
                      value: '${m['chamber_phone']}',
                      action: true,
                    ),
                  ),
                InsetRow(
                  chevron: false,
                  onTap: showMobile && '${m['mobile'] ?? ''}'.isNotEmpty
                      ? () => _dial('${m['mobile']}')
                      : null,
                  child: showMobile
                      ? _ContactLine(
                          icon: Icons.phone_outlined,
                          value: '${m['mobile'] ?? '—'}',
                          action: true,
                        )
                      : const _HiddenLine(icon: Icons.phone_outlined),
                ),
                InsetRow(
                  chevron: false,
                  onTap: showEmail && '${m['email'] ?? ''}'.isNotEmpty
                      ? () => _mail('${m['email']}')
                      : null,
                  child: showEmail
                      ? _ContactLine(
                          icon: Icons.mail_outline_rounded,
                          value: '${m['email'] ?? '—'}',
                          action: true,
                        )
                      : const _HiddenLine(icon: Icons.mail_outline_rounded),
                ),
              ],
            ),
            if (me.canPublish &&
                (m['hide_mobile'] == true || m['hide_email'] == true)) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Shown in full because you are an office bearer.',
                  style: T.caption,
                ),
              ),
            ],

            const SizedBox(height: 20),
            const SectionHeader('Committee positions'),
            if (current.isEmpty && past.isEmpty)
              const EmptyState('No committee positions on record.')
            else
              InsetGroup(
                children: [
                  for (final p in current)
                    InsetRow(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CommitteeDetailScreen(
                            id: (p['committees'] as Rec)['id'] as int,
                            me: me,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(p['committees'] as Rec?)?['name'] ?? ''}',
                            style: T.callout.copyWith(color: C.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p['designation'] ?? ''} · '
                            '${((p['committees'] as Rec?)?['committee_terms'] as Rec?)?['label'] ?? ''}',
                            style: T.record,
                          ),
                        ],
                      ),
                    ),
                  for (final p in past)
                    InsetRow(
                      chevron: false,
                      child: Text(
                        '${(p['committees'] as Rec?)?['name'] ?? ''} — '
                        '${p['designation'] ?? ''} '
                        '(${((p['committees'] as Rec?)?['committee_terms'] as Rec?)?['label'] ?? ''})',
                        style: T.caption,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    ),
  );

  static Future<void> _dial(String number) =>
      _open(Uri(scheme: 'tel', path: number));

  static Future<void> _mail(String address) =>
      _open(Uri(scheme: 'mailto', path: address));

  static Future<void> _open(Uri uri) async {
    // A handset without a dialler or mail client is a normal state, not a
    // fault — nothing to report, nothing to crash.
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.value,
    this.action = false,
  });

  final IconData icon;
  final String value;
  final bool action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: C.ink4),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value,
          style: T.callout.copyWith(color: action ? C.accent : C.ink),
        ),
      ),
    ],
  );
}

class _HiddenLine extends StatelessWidget {
  const _HiddenLine({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: C.ink5),
      const SizedBox(width: 12),
      const Icon(Icons.visibility_off_outlined, size: 14, color: C.ink5),
      const SizedBox(width: 6),
      Text('Hidden by member', style: T.callout.copyWith(color: C.ink5)),
    ],
  );
}
