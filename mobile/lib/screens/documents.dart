import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';
import 'announcements.dart' show FilterPill;
import 'chrome.dart';
import 'document_detail.dart';

/// Mirrors src/app/(app)/documents — the library, filtered by folder and search.
/// Uploading stays on the web: it needs a file picker and a storage round-trip
/// that no member has asked for on a handset.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.me});

  final Me me;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _search = TextEditingController();
  String _q = '';
  int? _folder;
  int _token = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
                'Document Library',
                eyebrow: 'Association record',
                sub: 'Constitution, circulars, minutes, forms and records.',
              ),

              AppInput(
                controller: _search,
                placeholder: 'Search by title, description or tag',
                prefix: Icons.search_rounded,
                onSubmitted: (v) => setState(() {
                  _q = v;
                  _token++;
                }),
              ),
              const SizedBox(height: 12),

              Loader<List<Rec>>(
                key: ValueKey('folders-$_token'),
                load: Data.folders,
                errorMessage: 'Folders could not be loaded.',
                placeholder: const SizedBox(height: 34),
                builder: (_, folders) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 7,
                    children: [
                      FilterPill(
                        label: 'All documents',
                        selected: _folder == null,
                        onTap: () => setState(() {
                          _folder = null;
                          _token++;
                        }),
                      ),
                      for (final f in folders)
                        FilterPill(
                          label: '${f['name']}',
                          selected: _folder == f['id'],
                          onTap: () => setState(() {
                            _folder = f['id'] as int;
                            _token++;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Loader<List<Rec>>(
                key: ValueKey('docs-$_q-$_folder-$_token'),
                load: () => Data.documents(q: _q, folderId: _folder),
                errorMessage: 'The library could not be loaded.',
                placeholder: const SkeletonCard(lines: 5),
                builder: (context, rows) => rows.isEmpty
                    ? const EmptyState(
                        'No documents match. Note that some documents are '
                        'restricted to committee members.',
                      )
                    : InsetGroup(
                        children: [
                          for (final d in rows)
                            InsetRow(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DocumentDetailScreen(
                                    id: d['id'] as int,
                                    me: widget.me,
                                  ),
                                ),
                              ),
                              child: _DocumentLine(
                                row: d,
                                showDownloads: widget.me.isStaff,
                              ),
                            ),
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

class _DocumentLine extends StatelessWidget {
  const _DocumentLine({required this.row, required this.showDownloads});

  final Rec row;
  final bool showDownloads;

  @override
  Widget build(BuildContext context) {
    final versions = (row['document_versions'] as List? ?? const [])
        .cast<Rec>()
        .toList()
      ..sort(
        (a, b) => ((b['version'] as num?) ?? 0).compareTo(
          (a['version'] as num?) ?? 0,
        ),
      );
    final latest = versions.isEmpty ? null : versions.first;
    final tags = (row['tags'] as List? ?? const []).cast<String>().take(4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.description_outlined, size: 20, color: C.ink4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row['title']}',
                style: T.headline.copyWith(fontSize: 15),
              ),
              if ('${row['description'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  '${row['description']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.footnote,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                [
                  '${(row['folders'] as Rec?)?['name'] ?? 'Uncategorised'}',
                  day(row['created_at']),
                  fileSize(latest?['size_bytes']),
                  if (showDownloads) '${row['download_count']} downloads',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.record,
              ),
              if (row['visibility'] != 'all_members' ||
                  ((latest?['version'] as num?) ?? 1) > 1 ||
                  tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (row['visibility'] != 'all_members')
                      Tag(
                        visibilityLabel[row['visibility']] ??
                            humanise(row['visibility']),
                        tone: Tone.warn,
                      ),
                    if (((latest?['version'] as num?) ?? 1) > 1)
                      Tag('v${latest?['version']}'),
                    for (final t in tags) Tag(t),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
