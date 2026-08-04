import 'package:flutter/material.dart';

import '../data.dart';
import '../format.dart';
import '../theme.dart';
import '../ui.dart';

/// Mirrors src/app/(app)/settings. PRD 3.2 splits the record in two: contact
/// details, bio, practice areas and privacy are self-service; name, enrolment
/// number and designation go to the office's moderation queue.
const _moderated = ['full_name', 'enrolment_no'];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.me});

  final Me me;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _fullName = TextEditingController(text: widget.me.fullName);
  late final _enrolment = TextEditingController(text: widget.me.enrolmentNo);
  late final _mobile = TextEditingController(text: _s('mobile'));
  late final _chamberPhone = TextEditingController(text: _s('chamber_phone'));
  late final _chamberAddress = TextEditingController(
    text: _s('chamber_address'),
  );
  late final _practiceAreas = TextEditingController(
    text: (widget.me.row['practice_areas'] as List? ?? const [])
        .cast<String>()
        .join(', '),
  );
  late final _bio = TextEditingController(text: _s('bio'));

  late bool _hideMobile = widget.me.row['hide_mobile'] == true;
  late bool _hideEmail = widget.me.row['hide_email'] == true;

  Map<String, bool> _prefs = {};
  bool _prefsLoaded = false;
  bool _saving = false;
  bool _rotating = false;
  int _token = 0;

  String _s(String key) => '${widget.me.row[key] ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _enrolment,
      _mobile,
      _chamberPhone,
      _chamberAddress,
      _practiceAreas,
      _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final rows = await Data.notificationPrefs();
      if (!mounted) return;
      setState(() {
        _prefs = {
          for (final r in rows)
            '${r['category']}': r['email_enabled'] != false,
        };
        _prefsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _prefsLoaded = true);
    }
  }

  bool _enabled(String category) => _prefs[category] ?? true;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Data.saveProfile(
        memberId: widget.me.id,
        mobile: _mobile.text,
        chamberPhone: _chamberPhone.text,
        chamberAddress: _chamberAddress.text,
        bio: _bio.text,
        practiceAreas: _practiceAreas.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        hideMobile: _hideMobile,
        hideEmail: _hideEmail,
      );

      // A moderated field never writes straight through — it is filed as a
      // request and the office decides.
      var queued = 0;
      for (final field in _moderated) {
        final next = (field == 'full_name' ? _fullName : _enrolment).text
            .trim();
        final current = '${widget.me.row[field] ?? ''}';
        if (next.isNotEmpty && next != current) {
          await Data.requestProfileChange(
            memberId: widget.me.id,
            field: field,
            oldValue: current,
            newValue: next,
          );
          queued++;
        }
      }

      if (!mounted) return;
      _say(
        queued == 0
            ? 'Your profile has been saved.'
            : 'Saved. $queued change${queued == 1 ? '' : 's'} sent to the '
                  'Association office for approval.',
      );
    } catch (_) {
      if (mounted) _say('Your profile could not be saved. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rotate() async {
    setState(() => _rotating = true);
    try {
      await Data.rotateIcsToken(widget.me.id);
      if (mounted) setState(() => _token++);
    } catch (_) {
      if (mounted) _say('The feed link could not be regenerated.');
    } finally {
      if (mounted) setState(() => _rotating = false);
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
    title: 'Settings',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 40),
      children: [
        const PageHeading(
          'Settings',
          sub: 'Your profile, privacy and notification preferences.',
        ),

        // ── Profile ────────────────────────────────────────────────────
        const SectionHeader('Profile'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppField(
                label: 'Full name',
                hint: 'Changes require approval by the Association office.',
                child: AppInput(controller: _fullName),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Enrolment number',
                hint: 'Changes require approval.',
                child: AppInput(controller: _enrolment),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Mobile',
                child: AppInput(
                  controller: _mobile,
                  keyboard: TextInputType.phone,
                ),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Chamber phone',
                child: AppInput(
                  controller: _chamberPhone,
                  keyboard: TextInputType.phone,
                ),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Chamber address',
                child: AppInput(controller: _chamberAddress),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Practice areas',
                hint: 'Separate with commas.',
                child: AppInput(controller: _practiceAreas),
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Short bio',
                hint: 'Up to 500 characters.',
                child: AppInput(controller: _bio, maxLines: 4),
              ),
            ],
          ),
        ),

        // ── Privacy ────────────────────────────────────────────────────
        const SizedBox(height: 24),
        const SectionHeader('Privacy'),
        InsetGroup(
          children: [
            _SwitchRow(
              label: 'Hide my mobile number',
              value: _hideMobile,
              onChanged: (v) => setState(() => _hideMobile = v),
            ),
            _SwitchRow(
              label: 'Hide my email address',
              value: _hideEmail,
              onChanged: (v) => setState(() => _hideEmail = v),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Office bearers can always see your full contact details.',
            style: T.caption,
          ),
        ),

        const SizedBox(height: 24),
        AppButton(
          'Save changes',
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),

        // ── Email notifications ────────────────────────────────────────
        const SizedBox(height: 24),
        const SectionHeader('Email notifications'),
        if (!_prefsLoaded)
          const SkeletonCard(lines: 4)
        else
          InsetGroup(
            children: [
              for (final e in categoryLabel.entries)
                _SwitchRow(
                  label: e.value,
                  // Urgent announcements are non-optional (PRD 4.2).
                  value: e.key == 'urgent' ? true : _enabled(e.key),
                  locked: e.key == 'urgent',
                  trailing: e.key == 'urgent'
                      ? const Tag('Always on', tone: Tone.alert)
                      : null,
                  onChanged: (v) async {
                    setState(() => _prefs[e.key] = v);
                    try {
                      await Data.setNotificationPref(
                        memberId: widget.me.id,
                        category: e.key,
                        enabled: v,
                      );
                    } catch (_) {
                      if (!mounted) return;
                      setState(() => _prefs[e.key] = !v);
                      _say('That preference could not be saved.');
                    }
                  },
                ),
            ],
          ),

        // ── Calendar subscription ──────────────────────────────────────
        const SizedBox(height: 24),
        const SectionHeader('Calendar subscription'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A private feed of your association calendar for Google or '
                'Apple Calendar. Anyone with this link can read your calendar '
                '— rotate it if it is ever shared by accident.',
                style: T.footnote,
              ),
              const SizedBox(height: 12),
              Loader<Rec?>(
                key: ValueKey('ics-$_token'),
                load: Data.icsToken,
                errorMessage: 'The feed link could not be read.',
                placeholder: const SizedBox(height: 36),
                builder: (_, token) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (token != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: C.canvas,
                          borderRadius: BorderRadius.circular(kRControl),
                          border: Border.all(color: C.separator, width: 0.5),
                        ),
                        child: SelectableText(
                          '/api/ics/${token['token']}',
                          style: T.record.copyWith(color: C.ink2),
                        ),
                      )
                    else
                      Text(
                        'No feed link has been generated yet.',
                        style: T.footnote,
                      ),
                    const SizedBox(height: 12),
                    AppButton(
                      token != null
                          ? 'Revoke and generate a new link'
                          : 'Generate feed link',
                      variant: BtnVariant.outline,
                      expand: true,
                      busy: _rotating,
                      onPressed: _rotate,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Session ────────────────────────────────────────────────────
        const SizedBox(height: 24),
        const SectionHeader('Session'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.me.fullName} · ${widget.me.email ?? widget.me.enrolmentNo}',
                style: T.footnote,
              ),
              const SizedBox(height: 12),
              AppButton(
                'Sign out',
                variant: BtnVariant.danger,
                expand: true,
                icon: Icons.logout_rounded,
                // AuthGate is listening; signing out swaps the screen itself.
                onPressed: Data.signOut,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.locked = false,
    this.trailing,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool locked;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InsetRow(
    chevron: false,
    padding: const EdgeInsets.fromLTRB(16, 2, 10, 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: T.callout.copyWith(color: locked ? C.ink3 : C.ink),
          ),
        ),
        if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
        Switch(
          value: value,
          activeThumbColor: C.onDark,
          activeTrackColor: C.ink,
          inactiveTrackColor: C.sunk,
          onChanged: locked ? null : onChanged,
        ),
      ],
    ),
  );
}
