import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghcba/data.dart';
import 'package:ghcba/format.dart';
import 'package:ghcba/main.dart';
import 'package:ghcba/screens/login.dart';
import 'package:ghcba/theme.dart';
import 'package:ghcba/ui.dart';

/*
  The smallest checks that fail if the logic breaks: the label/date helpers the
  whole app formats records with, the calendar treatments PRD 3.4 requires to be
  distinguishable, and one render of the only screen a signed-out member sees.

  Importing main.dart also forces the entire screen graph through the compiler,
  so this doubles as the build check on a machine with no Android SDK.
*/

void main() {
  // Keeps the analyzer honest that main.dart is genuinely reachable here.
  assert(GhcbaApp != Null);

  group('format', () {
    test('humanise turns an enum value into a label', () {
      expect(humanise('court_notice'), 'Court Notice');
      expect(humanise('agm'), 'Agm');
      expect(humanise(null), '');
    });

    test('ago reports one unit, and singularises it', () {
      final now = DateTime.now();
      expect(ago(now.subtract(const Duration(seconds: 1))), '1 second ago');
      expect(ago(now.subtract(const Duration(minutes: 5))), '5 minutes ago');
      expect(ago(now.subtract(const Duration(hours: 3))), '3 hours ago');
      expect(ago(now.subtract(const Duration(days: 1))), '1 day ago');
      expect(ago(now.subtract(const Duration(days: 40))), '1 month ago');
      expect(ago(now.subtract(const Duration(days: 400))), '1 year ago');
    });

    test('relativeDay names today and tomorrow', () {
      final now = DateTime.now();
      expect(relativeDay(now), 'Today');
      expect(relativeDay(now.add(const Duration(days: 1))), 'Tomorrow');
      // Far enough out that it can never collide with Today/Tomorrow.
      expect(relativeDay(now.add(const Duration(days: 9))), isNot('Today'));
    });

    test('fileSize crosses from KB to MB, and marks an absent size', () {
      expect(fileSize(null), '—');
      expect(fileSize(0), '—');
      expect(fileSize(2400), '2 KB');
      expect(fileSize(2400000), '2.4 MB');
    });

    test('every enum value the schema can emit has a label', () {
      // A missing label renders as a raw enum value in front of a member.
      for (final v in ['general', 'court_notice', 'condolence', 'election',
        'welfare_scheme', 'meeting_notice', 'urgent']) {
        expect(categoryLabel[v], isNotNull, reason: 'category $v');
      }
      for (final v in ['court_holiday', 'association_meeting', 'gbm_egm',
        'event', 'election', 'hearing_of_interest', 'other']) {
        expect(entryTypeLabel[v], isNotNull, reason: 'entry type $v');
      }
      for (final v in ['seminar', 'cle_training', 'cultural', 'sports',
        'felicitation', 'agm', 'farewell', 'other']) {
        expect(eventTypeLabel[v], isNotNull, reason: 'event type $v');
      }
    });
  });

  group('calendar treatments', () {
    test('PRD 3.4: entry types stay apart in a monochrome palette', () {
      // The palette carries no hue, so the types must separate by treatment.
      // If two collapse onto the same fill+border+ink, a holiday stops being
      // distinguishable from a meeting at a glance.
      final seen = <String>{};
      for (final type in entryTypeLabel.keys) {
        final s = entryStyle(type);
        final key = '${s.bg.toARGB32()}/${s.fg.toARGB32()}/${s.border.toARGB32()}';
        expect(seen.add(key), isTrue, reason: '$type duplicates another type');
      }
    });

    test('a court holiday is the one that carries the accent', () {
      expect(entryStyle('court_holiday').bg, C.accent);
    });

    test('an unknown type falls back rather than throwing', () {
      expect(() => entryStyle('something_new'), returnsNormally);
    });
  });

  group('ui', () {
    testWidgets('the login screen renders its fields and action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildTheme(), home: const LoginScreen()),
      );

      expect(find.text('Bar Association'), findsOneWidget);
      expect(find.text('Enrolment number or mobile'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    test('demo mode is on, so the sign-in gate is never reached', () {
      // The gate still exists for builds with demo mode switched off; this
      // pins that the shipped configuration skips it.
      expect(demoMode, isTrue);
      expect(demoEmail, 'demo@gmail.com');
    });

    testWidgets('an empty state states an instruction, never a blank card', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyState('No notices have been published.')),
        ),
      );
      expect(find.text('No notices have been published.'), findsOneWidget);
    });

    testWidgets('a failed section offers a retry that re-runs the query', (
      tester,
    ) async {
      // First attempt fails, second succeeds — the transient-failure case the
      // retry exists for.
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Loader<int>(
              load: () async {
                if (calls++ == 0) throw StateError('unreachable');
                return 42;
              },
              builder: (_, v) => Text('$v'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });
}
