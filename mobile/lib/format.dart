import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme.dart';

/* Ported from src/lib/format.ts so the app labels a record exactly as the web does. */

DateTime at(dynamic v) => DateTime.parse(v.toString()).toLocal();

String day(dynamic d) => DateFormat('d MMM yyyy').format(at(d));
String dayTime(dynamic d) => DateFormat('d MMM yyyy, h:mm a').format(at(d));
String time(dynamic d) => DateFormat('h:mm a').format(at(d));
String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
String monthAbbrev(DateTime d) => DateFormat('MMM').format(d);

/// "Tuesday, 4 August 2026" — the dashboard's dateline, as the web sets it
/// with toLocaleDateString('en-IN', { weekday, day, month, year }).
String dayOfWeekLine(DateTime d) => DateFormat('EEEE, d MMMM yyyy').format(d);

/// "3 days ago" — the strict, single-unit form date-fns produces.
String ago(dynamic d) {
  final diff = DateTime.now().difference(at(d));
  final s = diff.inSeconds.abs();
  final (n, unit) = switch (s) {
    < 60 => (s, 'second'),
    < 3600 => (s ~/ 60, 'minute'),
    < 86400 => (s ~/ 3600, 'hour'),
    < 2592000 => (s ~/ 86400, 'day'),
    < 31536000 => (s ~/ 2592000, 'month'),
    _ => (s ~/ 31536000, 'year'),
  };
  return '$n $unit${n == 1 ? '' : 's'} ago';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String relativeDay(dynamic d) {
  final date = at(d);
  final now = DateTime.now();
  if (_sameDay(date, now)) return 'Today';
  if (_sameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
  return DateFormat('EEE d MMM').format(date);
}

/// enum_value → Enum Value
String humanise(String? s) => (s ?? '')
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

const designationLabel = {
  'senior_advocate': 'Senior Advocate',
  'advocate': 'Advocate',
  'advocate_on_record': 'Advocate-on-Record',
};

const categoryLabel = {
  'general': 'General',
  'court_notice': 'Court Notice',
  'condolence': 'Condolence',
  'election': 'Election',
  'welfare_scheme': 'Welfare Scheme',
  'meeting_notice': 'Meeting Notice',
  'urgent': 'Urgent',
};

const entryTypeLabel = {
  'court_holiday': 'Court Holiday',
  'association_meeting': 'Association Meeting',
  'gbm_egm': 'GBM / EGM',
  'event': 'Event',
  'election': 'Election',
  'hearing_of_interest': 'Hearing of Interest',
  'other': 'Other',
};

const eventTypeLabel = {
  'seminar': 'Seminar',
  'cle_training': 'CLE / Training',
  'cultural': 'Cultural',
  'sports': 'Sports',
  'felicitation': 'Felicitation',
  'agm': 'AGM',
  'farewell': 'Farewell',
  'other': 'Other',
};

const ticketCategoryLabel = {
  'general': 'General Enquiry',
  'membership': 'Membership',
  'welfare_scheme': 'Welfare Scheme',
  'grievance': 'Grievance',
  'technical_support': 'Technical Support',
  'other': 'Other',
};

const visibilityLabel = {
  'all_members': 'All Members',
  'committee_only': 'Committee Only',
  'office_bearers_only': 'Office Bearers Only',
};

String fileSize(dynamic b) {
  final n = b is num ? b.toInt() : int.tryParse('${b ?? ''}') ?? 0;
  if (n <= 0) return '—';
  if (n > 1000000) return '${(n / 1000000).toStringAsFixed(1)} MB';
  return '${(n / 1000).round()} KB';
}

/// Calendar colour-coding — holidays must read differently at a glance (PRD 3.4).
/// The palette is monochrome, so the types separate by treatment instead of hue:
/// red fill, solid black, outline, grey fill, hairline.
({Color bg, Color fg, Color border}) entryStyle(String type) => switch (type) {
  'court_holiday' => (bg: C.accent, fg: C.onDark, border: C.accent),
  'gbm_egm' => (bg: C.ink, fg: C.onDark, border: C.ink),
  'election' => (bg: C.accentWash, fg: C.accent, border: C.accentWash),
  'association_meeting' => (bg: C.surface, fg: C.ink, border: C.ink),
  'event' => (bg: C.sunk, fg: C.ink2, border: C.sunk),
  'hearing_of_interest' => (bg: C.surface, fg: C.ink3, border: C.separator),
  _ => (bg: C.canvas, fg: C.ink4, border: C.separator),
};
