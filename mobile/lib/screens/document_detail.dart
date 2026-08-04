import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';

/// Mirrors src/app/(app)/documents/[id]. Where the web previews the file in an
/// iframe, the app hands the signed URL to the platform — the handset already
/// has a PDF viewer, and shipping a second one would be the wrong trade.
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({super.key, required this.id, required this.me});

  final int id;
  final Me me;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _opening = false;

  Future<void> _open(String path) async {
    setState(() => _opening = true);
    // The bucket is private: the link is minted per tap and expires, so it
    // cannot outlive the permission that produced it.
    final url = await Data.signedUrl(path);
    if (!mounted) return;
    setState(() => _opening = false);

    if (url == null) {
      _say('That file could not be opened. It may have been withdrawn.');
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _say('No app on this device can open that file.');
    }
  }

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: T.footnote.copyWith(color: C.onDark)),
      backgroundColor: C.ink,
      behavior: SnackBarBehavior.floating,
    ),
  );

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: 'Document',
    child: Loader<Rec?>(
      load: () => Data.document(widget.id),
      errorMessage: 'This document could not be loaded.',
      placeholder: const Padding(
        padding: EdgeInsets.all(kGutter),
        child: SkeletonCard(lines: 5),
      ),
      builder: (context, d) {
        if (d == null) {
          return const Padding(
            padding: EdgeInsets.all(kGutter),
            child: EmptyState('This document is no longer available.'),
          );
        }

        final versions = (d['document_versions'] as List? ?? const [])
            .cast<Rec>()
            .toList()
          ..sort(
            (a, b) => ((b['version'] as num?) ?? 0).compareTo(
              (a['version'] as num?) ?? 0,
            ),
          );
        final latest = versions.isEmpty ? null : versions.first;
        final path = latest?['file_path'] as String?;
        final tags = (d['tags'] as List? ?? const []).cast<String>();
        final uploader = d['members'] as Rec?;

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
                      const Icon(
                        Icons.description_outlined,
                        size: 26,
                        color: C.ink4,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('${d['title']}', style: T.title2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Tag(
                        '${(d['folders'] as Rec?)?['name'] ?? 'Uncategorised'}',
                        tone: Tone.info,
                      ),
                      if (d['visibility'] != 'all_members')
                        Tag(
                          visibilityLabel[d['visibility']] ??
                              humanise(d['visibility']),
                          tone: Tone.warn,
                        ),
                      if (latest != null) Tag('Version ${latest['version']}'),
                    ],
                  ),
                  if ('${d['description'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${d['description']}',
                      style: T.body.copyWith(fontSize: 15, color: C.ink2),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final t in tags) Tag(t)],
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(height: 0.5, color: C.separator),
                  ),

                  if (path != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(kRControl),
                      child: DotField(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 26),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(kRControl),
                            border: Border.all(color: C.separator, width: 0.5),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.insert_drive_file_outlined,
                                size: 28,
                                color: C.ink4,
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  '${latest?['file_name'] ?? ''}',
                                  textAlign: TextAlign.center,
                                  style: T.footnote.copyWith(color: C.ink2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      'Open file',
                      icon: Icons.open_in_new_rounded,
                      expand: true,
                      busy: _opening,
                      onPressed: () => _open(path),
                    ),
                  ] else
                    const EmptyState(
                      'This record has no file in storage. Upload one from the '
                      'document library on the web.',
                    ),

                  const SizedBox(height: 16),
                  Text(
                    [
                      fileSize(latest?['size_bytes']),
                      'Uploaded ${dayTime(d['created_at'])}',
                      if (uploader != null) 'by ${uploader['full_name']}',
                      if (widget.me.isStaff)
                        '${d['download_count']} downloads',
                    ].join(' · '),
                    style: T.caption,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const SectionHeader('Version history'),
            if (versions.isEmpty)
              const EmptyState('No versions recorded.')
            else
              InsetGroup(
                children: [
                  for (final v in versions)
                    InsetRow(
                      chevron: false,
                      child: Row(
                        children: [
                          Tag(
                            'v${v['version']}',
                            tone: v['version'] == latest?['version']
                                ? Tone.success
                                : Tone.neutral,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${v['file_name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.callout.copyWith(color: C.ink),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dayTime(v['created_at']) +
                                      ((v['members'] as Rec?) != null
                                          ? ' · ${(v['members'] as Rec)['full_name']}'
                                          : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.record,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(fileSize(v['size_bytes']), style: T.record),
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
