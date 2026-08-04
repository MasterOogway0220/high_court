import 'package:flutter/material.dart';

/*
  GHCBA — Apple structure, Nothing accents.

  The web dashboard runs a yellow-and-black "Donezo" direction. The app takes a
  different one on purpose: iOS layout grammar (large titles, inset grouped lists,
  hairline separators, generous whitespace) carrying a Nothing-style monochrome
  palette with a single red accent.

  Two families, two jobs. Inter sets everything a member reads — a bar association
  circulates dense text and half its members are reading it at arm's length, so body
  copy stays in a humanist sans. Doto, a dot-matrix face, is reserved for figures and
  eyebrow labels, where the pattern is the point and legibility costs nothing.
*/

class C {
  C._();

  // Surfaces, outermost to innermost. iOS grouped-background stack.
  static const canvas = Color(0xFFF2F2F7); // the page behind cards
  static const surface = Color(0xFFFFFFFF); // a card
  static const sunk = Color(0xFFE9E9EF); // search field, pressed state
  static const separator = Color(0xFFD8D8DE); // every hairline

  // Ink. True neutrals so red is the only hue in the room.
  static const ink = Color(0xFF000000);
  static const ink2 = Color(0xFF3C3C43); // secondary label
  static const ink3 = Color(0xFF6E6E73); // tertiary label
  static const ink4 = Color(0xFF9A9AA0); // quaternary — timestamps, hints
  static const ink5 = Color(0xFFC4C4C8); // disabled, placeholder

  /// The only hue. Used for urgency, the unread dot, and the live accent —
  /// never for decoration, or it stops meaning anything.
  static const accent = Color(0xFFD71921);
  static const accentWash = Color(0xFFFDECEC);

  static const onDark = Color(0xFFFFFFFF);
  static const board = Color(0xFF0A0A0A); // the dark panel
}

class T {
  T._();

  static const _i = 'Inter';
  static const _d = 'Doto';

  // Apple's type scale, near enough: 34 / 28 / 22 / 20 / 17 / 16 / 15 / 13 / 12.
  static const largeTitle = TextStyle(
    fontFamily: _i,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.8,
    color: C.ink,
  );
  static const title1 = TextStyle(
    fontFamily: _i,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: C.ink,
  );
  static const title2 = TextStyle(
    fontFamily: _i,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.35,
    color: C.ink,
  );
  static const title3 = TextStyle(
    fontFamily: _i,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.25,
    color: C.ink,
  );
  static const headline = TextStyle(
    fontFamily: _i,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.2,
    color: C.ink,
  );
  static const body = TextStyle(
    fontFamily: _i,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.2,
    color: C.ink,
  );
  static const callout = TextStyle(
    fontFamily: _i,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.15,
    color: C.ink2,
  );
  static const subhead = TextStyle(
    fontFamily: _i,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: C.ink3,
  );
  static const footnote = TextStyle(
    fontFamily: _i,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: C.ink3,
  );
  static const caption = TextStyle(
    fontFamily: _i,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: C.ink4,
  );

  /// Small uppercase section label. Dot-matrix, widely tracked — the app's
  /// most repeated Nothing cue.
  static const eyebrow = TextStyle(
    fontFamily: _d,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 2.2,
    color: C.ink3,
  );

  /// A headline figure. Dot-matrix at size, where the grid reads as a pattern.
  static const figure = TextStyle(
    fontFamily: _d,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 1,
    color: C.ink,
  );

  /// A record number, date or reference set beside body text.
  static const record = TextStyle(
    fontFamily: _d,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.8,
    color: C.ink4,
  );
}

/// Corner radii. 12 for a card, 10 for a control — iOS proportions.
const kRCard = 12.0;
const kRControl = 10.0;
const kGutter = 16.0;

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: C.ink,
    onPrimary: C.onDark,
    secondary: C.accent,
    onSecondary: C.onDark,
    surface: C.surface,
    onSurface: C.ink,
    error: C.accent,
    onError: C.onDark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.canvas,
    fontFamily: 'Inter',
    splashFactory: InkSparkle.splashFactory,
    dividerColor: C.separator,
    // The app draws its own headers; the system bar stays out of the way.
    appBarTheme: const AppBarTheme(
      backgroundColor: C.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: T.title3,
      iconTheme: IconThemeData(color: C.ink, size: 22),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.accent,
      selectionColor: Color(0x33D71921),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: C.ink,
      linearMinHeight: 2,
    ),
  );
}
