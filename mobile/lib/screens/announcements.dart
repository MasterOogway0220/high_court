import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'announcement_detail.dart';
import 'chrome.dart';

/// Mirrors src/app/(app)/announcements/page.tsx — the published feed, with the
/// archive behind a toggle (PRD 3.3).
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.me});

  final Me me;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _category;
  bool _archive = false;
  int _token = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _token++);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppHeader(me: widget.me),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          color: C.ink,
          backgroundColor: C.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 32),
            children: [
              const PageHeading(
                'Announcements',
                eyebrow: 'Association record',
                sub: 'Circulars, court notices and communications of the '
                    'Association.',
              ),

              AppInput(
                controller: _search,
                placeholder: 'Search notices',
                prefix: Icons.search_rounded,
                onSubmitted: (v) => setState(() {
                  _q = v;
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
                      label: 'All',
                      selected: _category == null,
                      onTap: () => setState(() {
                        _category = null;
                        _token++;
                      }),
                    ),
                    for (final e in categoryLabel.entries)
                      FilterPill(
                        label: e.value,
                        selected: _category == e.key,
                        onTap: () => setState(() {
                          _category = e.key;
                          _token++;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // PRD 3.3: expired notices leave the feed but stay in the archive.
              InsetGroup(
                children: [
                  InsetRow(
                    chevron: false,
                    padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Include expired (archive)',
                            style: T.callout.copyWith(color: C.ink),
                          ),
                        ),
                        Switch(
                          value: _archive,
                          activeThumbColor: C.onDark,
                          activeTrackColor: C.ink,
                          inactiveTrackColor: C.sunk,
                          onChanged: (v) => setState(() {
                            _archive = v;
                            _token++;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Loader<List<Rec>>(
                key: ValueKey('list-$_token-$_q-$_category-$_archive'),
                load: () => Data.announcements(
                  q: _q,
                  category: _category,
                  archive: _archive,
                ),
                errorMessage: 'The notice feed could not be loaded.',
                placeholder: const Column(
                  children: [
                    SkeletonCard(),
                    SizedBox(height: 10),
                    SkeletonCard(),
                  ],
                ),
                builder: (_, rows) => rows.isEmpty
                    ? const EmptyState('No announcements match these filters.')
                    : Column(
                        children: [
                          for (final a in rows) ...[
                            AnnouncementCard(
                              row: a,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AnnouncementDetailScreen(
                                      id: a['id'] as int,
                                      me: widget.me,
                                    ),
                                  ),
                                );
                                // Opening a notice marks it read, so the unread
                                // dot has to be re-resolved on the way back.
                                _reload();
                              },
                            ),
                            const SizedBox(height: 10),
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

/// One notice in the feed. Urgent and condolence notices carry a left rule, as
/// the web marks them.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.row, this.onTap});

  final Rec row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final condolence = row['category'] == 'condolence';
    final priority = '${row['priority']}';
    final expiresAt = row['expires_at'];
    final expired =
        expiresAt != null && at(expiresAt).isBefore(DateTime.now());
    final unread =
        (row['announcement_reads'] as List? ?? const []).isEmpty;
    final files = (row['announcement_attachments'] as List? ?? const []).length;

    return AppCard(
      onTap: onTap,
      accentEdge: condolence
          ? C.ink4
          : priority == 'urgent'
          ? C.accent
          : priority == 'important'
          ? C.ink
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (row['pinned'] == true)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.push_pin_rounded, size: 11, color: C.accent),
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
                categoryLabel[row['category']] ?? humanise(row['category']),
                tone: condolence ? Tone.neutral : Tone.info,
              ),
              if (priority != 'normal' && !condolence)
                Tag(
                  humanise(priority),
                  tone: priority == 'urgent' ? Tone.alert : Tone.warn,
                ),
              if (row['visibility'] != 'all_members')
                Tag(
                  visibilityLabel[row['visibility']] ??
                      humanise(row['visibility']),
                  tone: Tone.warn,
                ),
              if (expired) const Tag('Expired'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${row['title']}',
                  style: T.title3.copyWith(
                    color: condolence ? C.ink2 : C.ink,
                  ),
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  height: 8,
                  width: 8,
                  decoration: const BoxDecoration(
                    color: C.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          if ('${row['body'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${row['body']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: T.footnote,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(day(row['publish_at']), style: T.record),
              const SizedBox(width: 8),
              Text('·', style: T.record),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ago(row['publish_at']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.record,
                ),
              ),
              if (files > 0) ...[
                const Icon(Icons.attach_file_rounded, size: 13, color: C.ink4),
                const SizedBox(width: 2),
                Text('$files', style: T.record),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A filter chip. Sized by its own padding so it works in a scrolling row and
/// in a Wrap alike.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? C.ink : C.surface,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? C.ink : C.separator,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: selected ? C.onDark : C.ink2,
          ),
        ),
      ),
    ),
  );
}
