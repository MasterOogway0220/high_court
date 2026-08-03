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
  court_holiday: 'bg-rule-wash text-rule border-rule-soft',
  association_meeting: 'bg-ink-100 text-ink-800 border-ink-200',
  gbm_egm: 'bg-amber-100 text-amber-900 border-amber-200',
  event: 'bg-emerald-100 text-emerald-900 border-emerald-200',
  election: 'bg-violet-100 text-violet-900 border-violet-200',
  hearing_of_interest: 'bg-sky-100 text-sky-900 border-sky-200',
  other: 'bg-paper-edge text-ink-700 border-paper-edge',
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
