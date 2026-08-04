import 'package:flutter/material.dart';
import 'theme.dart';

/*
  Primitives, mirroring src/lib/ui.tsx.

  Surfaces are white cards with a hairline edge; controls carry a 10px radius;
  status reads as a chip. Where the web draws an unfilled slot as a diagonal hatch,
  the app draws it as a dot field — same principle (an empty slot still reads as a
  slot), stated in the dot-matrix idiom the rest of the app speaks.
*/

/// The signature: a dot field standing in for a value not yet present.
class DotField extends StatelessWidget {
  const DotField({
    super.key,
    this.gap = 6,
    this.radius = 1,
    this.color = C.ink5,
    this.child,
  });

  final double gap;
  final double radius;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DotPainter(gap, radius, color), child: child);
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.gap, this.radius, this.color);

  final double gap;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), radius, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.gap != gap || old.radius != radius || old.color != color;
}

/// A card. White, hairline-edged — the unit the whole app is built from.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accentEdge,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// A left rule, as the web marks urgent and condolence notices.
  final Color? accentEdge;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(padding: padding, child: child);

    if (accentEdge != null) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: accentEdge),
          Expanded(child: body),
        ],
      );
    }

    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(kRCard),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRCard),
        splashColor: C.sunk,
        highlightColor: C.sunk,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRCard),
            border: Border.all(color: C.separator, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: body,
        ),
      ),
    );
  }
}

enum Tone { neutral, info, success, warn, alert }

/// A status chip. Five treatments that stay apart in a monochrome palette:
/// grey fill, outline, solid black, heavy outline, red wash.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = Tone.neutral});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    late Color bg, fg, border;
    switch (tone) {
      case Tone.neutral:
        bg = C.sunk;
        fg = C.ink3;
        border = Colors.transparent;
      case Tone.info:
        bg = Colors.transparent;
        fg = C.ink2;
        border = C.separator;
      case Tone.success:
        bg = C.ink;
        fg = C.onDark;
        border = Colors.transparent;
      case Tone.warn:
        bg = Colors.transparent;
        fg = C.ink;
        border = C.ink;
      case Tone.alert:
        bg = C.accentWash;
        fg = C.accent;
        border = Colors.transparent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          height: 1.2,
          color: fg,
        ),
      ),
    );
  }
}

enum BtnVariant { primary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = BtnVariant.primary,
    this.icon,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BtnVariant variant;
  final IconData? icon;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final off = onPressed == null || busy;

    late Color bg, fg, border;
    switch (variant) {
      case BtnVariant.primary:
        bg = off ? C.ink5 : C.ink;
        fg = C.onDark;
        border = Colors.transparent;
      case BtnVariant.outline:
        bg = C.surface;
        fg = off ? C.ink5 : C.ink;
        border = C.separator;
      case BtnVariant.ghost:
        bg = Colors.transparent;
        fg = off ? C.ink5 : C.ink2;
        border = Colors.transparent;
      case BtnVariant.danger:
        bg = C.accentWash;
        fg = C.accent;
        border = Colors.transparent;
    }

    return SizedBox(
      width: expand ? double.infinity : null,
      height: 48,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(kRControl),
        child: InkWell(
          onTap: off ? null : onPressed,
          borderRadius: BorderRadius.circular(kRControl),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRControl),
              border: Border.all(color: border, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: busy
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 17, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: T.headline.copyWith(color: fg, fontSize: 15),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// An empty state is an instruction, never a blank card (PRD 3.1).
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(kRCard),
    child: DotField(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRCard),
          border: Border.all(color: C.separator, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: T.footnote.copyWith(color: C.ink3),
        ),
      ),
    ),
  );
}

/// Page header: eyebrow, large title, one line of purpose, actions on the right.
class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.sub, this.eyebrow, this.aside});

  final String title;
  final String? sub;
  final String? eyebrow;
  final Widget? aside;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!.toUpperCase(), style: T.eyebrow),
                const SizedBox(height: 8),
              ],
              Text(title, style: T.largeTitle),
              if (sub != null) ...[
                const SizedBox(height: 6),
                Text(sub!, style: T.subhead),
              ],
            ],
          ),
        ),
        if (aside != null) ...[const SizedBox(width: 12), aside!],
      ],
    ),
  );
}

/// Section heading, with an optional "View all" on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onMore, this.moreLabel});

  final String title;
  final VoidCallback? onMore;
  final String? moreLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
    child: Row(
      children: [
        Expanded(child: Text(title.toUpperCase(), style: T.eyebrow)),
        if (onMore != null)
          GestureDetector(
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  moreLabel ?? 'View all',
                  style: T.footnote.copyWith(
                    color: C.ink2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 17, color: C.ink4),
              ],
            ),
          ),
      ],
    ),
  );
}

/// A labelled control, as Field does on the web.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: T.footnote.copyWith(color: C.ink2, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 7),
      child,
      if (hint != null) ...[
        const SizedBox(height: 6),
        Text(hint!, style: T.caption),
      ],
    ],
  );
}

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    this.controller,
    this.placeholder,
    this.obscure = false,
    this.keyboard,
    this.autofocus = false,
    this.onSubmitted,
    this.prefix,
    this.invalid = false,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final bool obscure;
  final TextInputType? keyboard;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefix;
  final bool invalid;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboard,
    autofocus: autofocus,
    onSubmitted: onSubmitted,
    maxLines: maxLines,
    style: T.body.copyWith(fontSize: 15),
    cursorColor: C.accent,
    decoration: InputDecoration(
      hintText: placeholder,
      hintStyle: T.body.copyWith(fontSize: 15, color: C.ink5),
      prefixIcon: prefix == null
          ? null
          : Icon(prefix, size: 18, color: C.ink4),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      filled: true,
      fillColor: C.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: _border(invalid ? C.accent : C.separator),
      enabledBorder: _border(invalid ? C.accent : C.separator),
      focusedBorder: _border(C.ink, width: 1.5),
    ),
  );

  static OutlineInputBorder _border(Color c, {double width = 0.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRControl),
        borderSide: BorderSide(color: c, width: width),
      );
}

/// A member's photograph, or their initials when there is none.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44});

  final String name;
  final String? url;
  final double size;

  static String initials(String name) {
    final parts = name.split(' ').where((w) => w.isNotEmpty).take(2);
    return parts.map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: C.sunk, shape: BoxShape.circle),
    child: Text(
      initials(name),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: size * 0.36,
        fontWeight: FontWeight.w600,
        color: C.ink2,
        height: 1,
      ),
    ),
  );
}

/// A loading placeholder, drawn as dot fields so a pending slot still reads
/// as a slot rather than a gap.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 11,
          width: 110,
          decoration: BoxDecoration(
            color: C.sunk,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < lines; i++) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              width: double.infinity,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: [1.0, 0.82, 0.64][i % 3],
                child: const DotField(gap: 5, radius: 1),
              ),
            ),
          ),
          if (i != lines - 1) const SizedBox(height: 9),
        ],
      ],
    ),
  );
}

/// The failure counterpart to EmptyState — a query that broke, not one that
/// returned nothing. Different fault, different instruction.
class ErrorState extends StatelessWidget {
  const ErrorState(this.message, {super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: Column(
      children: [
        const Icon(Icons.error_outline_rounded, size: 22, color: C.accent),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: T.footnote),
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          AppButton('Try again', variant: BtnVariant.outline, onPressed: onRetry),
        ],
      ],
    ),
  );
}

/// Every detail screen shares this chrome: a back affordance and a plain title.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.canvas,
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(title, style: T.title3),
      actions: actions,
    ),
    body: child,
  );
}

/// Runs one query and renders its three outcomes.
///
/// The web gives each dashboard widget its own Suspense boundary so a slow or
/// failing query degrades to a skeleton instead of taking the page down (PRD 3.1).
/// This is that boundary. Rebuild with a different [key] to re-run the query.
class Loader<D> extends StatefulWidget {
  const Loader({
    super.key,
    required this.load,
    required this.builder,
    this.placeholder,
    this.errorMessage = 'This section could not be loaded.',
  });

  final Future<D> Function() load;
  final Widget Function(BuildContext context, D data) builder;
  final Widget? placeholder;
  final String errorMessage;

  @override
  State<Loader<D>> createState() => _LoaderState<D>();
}

class _LoaderState<D> extends State<Loader<D>> {
  late Future<D> _future = widget.load();

  // A block body, not an arrow: `=> _future = widget.load()` returns the new
  // Future out of the closure, and setState rejects a callback that returns one.
  void _retry() {
    setState(() {
      _future = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<D>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return widget.placeholder ?? const SkeletonCard();
      }
      if (snap.hasError) {
        return ErrorState(widget.errorMessage, onRetry: _retry);
      }
      return widget.builder(context, snap.data as D);
    },
  );
}

/// A row in an inset grouped list, with the iOS chevron affordance.
class InsetRow extends StatelessWidget {
  const InsetRow({
    super.key,
    required this.child,
    this.onTap,
    this.chevron = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool chevron;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    splashColor: C.sunk,
    highlightColor: C.sunk,
    child: Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: child),
          if (chevron && onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: C.ink5),
            ),
        ],
      ),
    ),
  );
}

/// A white group with hairline separators between rows — the iOS inset list.
class InsetGroup extends StatelessWidget {
  const InsetGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 0.5, thickness: 0.5, color: C.separator),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(kRCard),
        border: Border.all(color: C.separator, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}
