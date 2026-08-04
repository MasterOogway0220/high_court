import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'announcements.dart' show FilterPill;
import 'chrome.dart';
import 'member_detail.dart';

const practiceAreas = [
  'Constitutional',
  'Criminal',
  'Civil',
  'Service',
  'Taxation',
  'Family Law',
  'Labour',
  'Environmental',
  'Company',
  'Land & Revenue',
  'Arbitration',
];

const _statuses = ['active', 'life', 'suspended', 'retired', 'deceased'];

/// Mirrors src/app/(app)/directory — search across name, enrolment number and
/// chamber, with the same filters the web offers, gathered into a sheet.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.me});

  final Me me;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _area;
  String? _designation;
  String? _status;
  String _sort = 'name';
  int _token = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _activeFilters =>
      (_area != null ? 1 : 0) +
      (_designation != null ? 1 : 0) +
      (_status != null ? 1 : 0);

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.canvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(kGutter),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Filters', style: T.title2),
                      ),
                      GestureDetector(
                        onTap: () {
                          setSheet(() {});
                          setState(() {
                            _area = null;
                            _designation = null;
                            _status = null;
                            _sort = 'name';
                            _token++;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(
                          'Clear all',
                          style: T.footnote.copyWith(
                            color: C.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const Text('PRACTICE AREA', style: T.eyebrow),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final a in practiceAreas)
                        FilterPill(
                          label: a,
                          selected: _area == a,
                          onTap: () {
                            setSheet(() {});
                            setState(() {
                              _area = _area == a ? null : a;
                              _token++;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('DESIGNATION', style: T.eyebrow),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final e in designationLabel.entries)
                        FilterPill(
                          label: e.value,
                          selected: _designation == e.key,
                          onTap: () {
                            setSheet(() {});
                            setState(() {
                              _designation = _designation == e.key
                                  ? null
                                  : e.key;
                              _token++;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('MEMBERSHIP STATUS', style: T.eyebrow),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final s in _statuses)
                        FilterPill(
                          label: humanise(s),
                          selected: _status == s,
                          onTap: () {
                            setSheet(() {});
                            setState(() {
                              _status = _status == s ? null : s;
                              _token++;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text('SORT', style: T.eyebrow),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final e in const [
                        ('name', 'Name (A–Z)'),
                        ('year', 'Enrolment year'),
                        ('recent', 'Recently joined'),
                      ])
                        FilterPill(
                          label: e.$2,
                          selected: _sort == e.$1,
                          onTap: () {
                            setSheet(() {});
                            setState(() {
                              _sort = e.$1;
                              _token++;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    'Show results',
                    expand: true,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
                'Member Directory',
                eyebrow: 'Association record',
                sub: "All enrolled members. Contact details respect each "
                    "member's privacy settings.",
              ),

              Row(
                children: [
                  Expanded(
                    child: AppInput(
                      controller: _search,
                      placeholder: 'Name, enrolment number, or chamber',
                      prefix: Icons.search_rounded,
                      onSubmitted: (v) => setState(() {
                        _q = v;
                        _token++;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    count: _activeFilters,
                    onTap: _openFilters,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Loader<List<Rec>>(
                key: ValueKey('$_q-$_area-$_designation-$_status-$_sort-$_token'),
                load: () => Data.members(
                  q: _q,
                  area: _area,
                  designation: _designation,
                  status: _status,
                  sort: _sort,
                ),
                errorMessage: 'The directory could not be loaded.',
                placeholder: const SkeletonCard(lines: 5),
                builder: (context, rows) {
                  if (rows.isEmpty) {
                    return const EmptyState(
                      'No members match these filters. Try widening your search.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, left: 4),
                        child: Text(
                          '${rows.length} member${rows.length == 1 ? '' : 's'}',
                          style: T.record,
                        ),
                      ),
                      InsetGroup(
                        children: [
                          for (final m in rows)
                            InsetRow(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MemberDetailScreen(
                                    id: '${m['id']}',
                                    me: widget.me,
                                  ),
                                ),
                              ),
                              child: _MemberLine(row: m),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({required this.row});

  final Rec row;

  @override
  Widget build(BuildContext context) {
    final areas = (row['practice_areas'] as List? ?? const [])
        .cast<String>()
        .take(2)
        .toList();
    final live = const {
      'active',
      'life',
    }.contains(row['membership_status']);

    return Row(
      children: [
        Avatar(
          name: '${row['full_name']}',
          url: row['photo_url'] as String?,
          size: 42,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row['full_name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.headline.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                '${row['enrolment_no']} · '
                '${designationLabel[row['designation']] ?? humanise(row['designation'])}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.record,
              ),
              if (areas.isNotEmpty) ...[
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final a in areas) Tag(a),
                    if (!live) Tag(humanise(row['membership_status']), tone: Tone.warn),
                  ],
                ),
              ] else if (!live) ...[
                const SizedBox(height: 7),
                Tag(humanise(row['membership_status']), tone: Tone.warn),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: count > 0 ? C.ink : C.surface,
        borderRadius: BorderRadius.circular(kRControl),
        border: Border.all(
          color: count > 0 ? C.ink : C.separator,
          width: 0.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.tune_rounded,
            size: 19,
            color: count > 0 ? C.onDark : C.ink2,
          ),
          if (count > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                height: 7,
                width: 7,
                decoration: const BoxDecoration(
                  color: C.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
