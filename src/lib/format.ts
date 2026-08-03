import { format, formatDistanceToNowStrict, isToday, isTomorrow } from 'date-fns'

export const day = (d: string | Date) => format(new Date(d), 'd MMM yyyy')
export const dayTime = (d: string | Date) => format(new Date(d), 'd MMM yyyy, h:mm a')
export const time = (d: string | Date) => format(new Date(d), 'h:mm a')
export const ago = (d: string | Date) => `${formatDistanceToNowStrict(new Date(d))} ago`

export function relativeDay(d: string | Date) {
  const date = new Date(d)
  if (isToday(date)) return 'Today'
  if (isTomorrow(date)) return 'Tomorrow'
  return format(date, 'EEE d MMM')
}

/** enum_value → Enum Value */
export const humanise = (s: string | null | undefined) =>
  (s ?? '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())

export const DESIGNATION: Record<string, string> = {
  senior_advocate: 'Senior Advocate',
  advocate: 'Advocate',
  advocate_on_record: 'Advocate-on-Record',
}

export const CATEGORY: Record<string, string> = {
  general: 'General',
  court_notice: 'Court Notice',
  condolence: 'Condolence',
  election: 'Election',
  welfare_scheme: 'Welfare Scheme',
  meeting_notice: 'Meeting Notice',
  urgent: 'Urgent',
}

export const ENTRY_TYPE: Record<string, string> = {
  court_holiday: 'Court Holiday',
  association_meeting: 'Association Meeting',
  gbm_egm: 'GBM / EGM',
  event: 'Event',
  election: 'Election',
  hearing_of_interest: 'Hearing of Interest',
  other: 'Other',
}

/** Calendar colour-coding — holidays must read differently at a glance (PRD 3.4). */
export const ENTRY_COLOUR: Record<string, string> = {
  court_holiday: 'bg-alert-wash text-alert border-alert-wash',
  association_meeting: 'bg-brand-50 text-brand-600 border-brand-50',
  gbm_egm: 'bg-warn-wash text-warn border-warn-wash',
  event: 'bg-info-wash text-info border-info-wash',
  election: 'bg-violet-50 text-violet-700 border-violet-50',
  hearing_of_interest: 'bg-ink-50 text-ink-700 border-ink-50',
  other: 'bg-paper-sunk text-ink-500 border-paper-sunk',
}

export const EVENT_TYPE: Record<string, string> = {
  seminar: 'Seminar',
  cle_training: 'CLE / Training',
  cultural: 'Cultural',
  sports: 'Sports',
  felicitation: 'Felicitation',
  agm: 'AGM',
  farewell: 'Farewell',
  other: 'Other',
}

export const TICKET_CATEGORY: Record<string, string> = {
  general: 'General Enquiry',
  membership: 'Membership',
  welfare_scheme: 'Welfare Scheme',
  grievance: 'Grievance',
  technical_support: 'Technical Support',
  other: 'Other',
}

export const VISIBILITY: Record<string, string> = {
  all_members: 'All Members',
  committee_only: 'Committee Only',
  office_bearers_only: 'Office Bearers Only',
}

export const fileSize = (b?: number | null) =>
  !b ? '—' : b > 1e6 ? `${(b / 1e6).toFixed(1)} MB` : `${Math.round(b / 1e3)} KB`
