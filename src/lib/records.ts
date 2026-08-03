import { CATEGORY, ENTRY_TYPE, EVENT_TYPE, TICKET_CATEGORY, VISIBILITY } from './format'

/*
  One schema drives every create/edit screen in the app.

  Authorisation is NOT here. Row-level security already decides who may write to each
  of these tables, so the server action does not re-check roles — the database refuses
  the write. What this file does provide is a field whitelist, which RLS cannot: without
  it a crafted form post could set download_count, or an id, or a foreign key it has no
  business setting.
*/

export type FieldType =
  | 'text'
  | 'textarea'
  | 'select'
  | 'date'
  | 'datetime'
  | 'checkbox'
  | 'number'
  | 'tags'

export type Field = {
  name: string
  label: string
  type: FieldType
  options?: Record<string, string>
  hint?: string
  required?: boolean
  rows?: number
  max?: number
  full?: boolean
}

export type RecordSpec = {
  table: string
  singular: string
  plural: string
  /** where to send the user after a save or delete */
  back: string
  /** columns to read when editing */
  fields: Field[]
  /** soft-delete instead of removing the row */
  softDelete?: boolean
}

const VIS: Field = {
  name: 'visibility',
  label: 'Visible to',
  type: 'select',
  options: VISIBILITY,
  hint: 'Restricted items never appear in searches or listings for members outside that group.',
}

export const RECORDS: Record<string, RecordSpec> = {
  announcements: {
    table: 'announcements',
    singular: 'Notice',
    plural: 'Announcements',
    back: '/announcements',
    fields: [
      { name: 'title', label: 'Title', type: 'text', required: true, full: true },
      { name: 'body', label: 'Body', type: 'textarea', rows: 12, required: true, full: true },
      { name: 'category', label: 'Category', type: 'select', options: CATEGORY },
      {
        name: 'priority',
        label: 'Priority',
        type: 'select',
        options: { normal: 'Normal', important: 'Important', urgent: 'Urgent' },
      },
      VIS,
      {
        name: 'status',
        label: 'Stage',
        type: 'select',
        options: { draft: 'Draft', review: 'In review', published: 'Published' },
        hint: 'Only published notices are visible to members.',
      },
      {
        name: 'publish_at',
        label: 'Publish at',
        type: 'datetime',
        hint: 'Set a future time to schedule it.',
      },
      { name: 'expires_at', label: 'Expires', type: 'datetime', hint: 'Leaves the feed, stays in the archive.' },
      { name: 'pinned', label: 'Pin to the top of the feed', type: 'checkbox', full: true },
    ],
  },

  events: {
    table: 'events',
    singular: 'Event',
    plural: 'Events',
    back: '/events',
    fields: [
      { name: 'title', label: 'Title', type: 'text', required: true, full: true },
      { name: 'description', label: 'Description', type: 'textarea', rows: 8, full: true },
      { name: 'event_type', label: 'Type', type: 'select', options: EVENT_TYPE },
      { name: 'venue', label: 'Venue', type: 'text' },
      { name: 'starts_at', label: 'Starts', type: 'datetime', required: true },
      { name: 'ends_at', label: 'Ends', type: 'datetime' },
      { name: 'capacity', label: 'Capacity', type: 'number', hint: 'Leave empty for no limit.' },
      { name: 'rsvp_deadline', label: 'RSVP closes', type: 'datetime' },
      VIS,
      { name: 'allow_guests', label: 'Members may bring accompanying persons', type: 'checkbox', full: true },
      { name: 'show_attendees', label: 'Show the attendee list to members', type: 'checkbox', full: true },
      { name: 'outcome_note', label: 'Outcome note', type: 'textarea', rows: 4, full: true },
    ],
  },

  calendar_entries: {
    table: 'calendar_entries',
    singular: 'Calendar entry',
    plural: 'Calendar',
    back: '/calendar',
    fields: [
      { name: 'title', label: 'Title', type: 'text', required: true, full: true },
      { name: 'entry_type', label: 'Type', type: 'select', options: ENTRY_TYPE },
      VIS,
      { name: 'starts_at', label: 'Starts', type: 'datetime', required: true },
      { name: 'ends_at', label: 'Ends', type: 'datetime' },
      { name: 'all_day', label: 'All day', type: 'checkbox', full: true },
      { name: 'description', label: 'Description', type: 'textarea', rows: 4, full: true },
    ],
  },

  documents: {
    table: 'documents',
    singular: 'Document',
    plural: 'Documents',
    back: '/documents',
    softDelete: true,
    fields: [
      { name: 'title', label: 'Title', type: 'text', required: true, full: true },
      { name: 'description', label: 'Description', type: 'textarea', rows: 4, full: true },
      { name: 'folder_id', label: 'Folder', type: 'select', options: {}, hint: 'Loaded from the library.' },
      VIS,
      { name: 'tags', label: 'Tags', type: 'tags', full: true, hint: 'Separate with commas.' },
    ],
  },

  newsletter_issues: {
    table: 'newsletter_issues',
    singular: 'Issue',
    plural: 'Newsletter',
    back: '/newsletter',
    fields: [
      { name: 'issue_no', label: 'Issue number', type: 'text', required: true },
      { name: 'period', label: 'Period', type: 'text', hint: 'For example, July 2026.' },
      { name: 'title', label: 'Title', type: 'text', required: true, full: true },
      { name: 'editorial', label: 'Editorial note', type: 'textarea', rows: 6, full: true },
      {
        name: 'status',
        label: 'Stage',
        type: 'select',
        options: { draft: 'Draft', review: 'In review', published: 'Published' },
      },
      { name: 'published_at', label: 'Published at', type: 'datetime' },
    ],
  },

  tickets: {
    table: 'tickets',
    singular: 'Enquiry',
    plural: 'Enquiries',
    back: '/admin',
    fields: [
      { name: 'subject', label: 'Subject', type: 'text', required: true, full: true },
      { name: 'category', label: 'Category', type: 'select', options: TICKET_CATEGORY },
      {
        name: 'status',
        label: 'Status',
        type: 'select',
        options: { open: 'Open', in_progress: 'In progress', resolved: 'Resolved' },
      },
      { name: 'message', label: 'Message', type: 'textarea', rows: 8, full: true },
    ],
  },

  members: {
    table: 'members',
    singular: 'Member',
    plural: 'Directory',
    back: '/directory',
    fields: [
      { name: 'full_name', label: 'Full name', type: 'text', required: true, full: true },
      { name: 'enrolment_no', label: 'Enrolment number', type: 'text', required: true },
      {
        name: 'designation',
        label: 'Designation',
        type: 'select',
        options: {
          senior_advocate: 'Senior Advocate',
          advocate: 'Advocate',
          advocate_on_record: 'Advocate-on-Record',
        },
      },
      { name: 'enrolment_date', label: 'Date of enrolment', type: 'date' },
      {
        name: 'membership_status',
        label: 'Status',
        type: 'select',
        options: {
          active: 'Active',
          life: 'Life',
          suspended: 'Suspended',
          retired: 'Retired',
          deceased: 'Deceased',
        },
      },
      { name: 'mobile', label: 'Mobile', type: 'text' },
      { name: 'email', label: 'Email', type: 'text' },
      { name: 'chamber_phone', label: 'Chamber phone', type: 'text' },
      { name: 'chamber_address', label: 'Chamber address', type: 'text', full: true },
      { name: 'practice_areas', label: 'Practice areas', type: 'tags', full: true },
      { name: 'bio', label: 'Bio', type: 'textarea', rows: 4, max: 500, full: true },
    ],
  },
}

export const specFor = (table: string): RecordSpec | undefined => RECORDS[table]
