# Product Requirements Document
## Guwahati High Court Bar Association — Member Dashboard

| | |
|---|---|
| **Product** | GHCBA Member Dashboard |
| **Client** | Guwahati High Court Bar Association |
| **Version** | 1.0 (Draft) |
| **Date** | 3 August 2026 |
| **Owner** | Kaizen Infotech Solutions Pvt. Ltd. |
| **Status** | For client review |

---

## 1. Overview

### 1.1 Purpose
A single, authenticated web dashboard that consolidates all association communication and records for GHCBA members — replacing the current mix of WhatsApp forwards, notice-board photographs, and ad-hoc PDF circulation.

### 1.2 Problem statement
- Circulars and cause-list notices reach members inconsistently and are impossible to search later.
- The member directory exists only as an outdated printed volume.
- Event and meeting information is scattered; attendance and RSVP are untracked.
- Association documents (bye-laws, forms, minutes, welfare scheme papers) have no canonical location.
- Committee composition and office-bearer contacts are unclear to junior members.

### 1.3 Goals
| Goal | Success measure |
|---|---|
| Single source of truth for association communication | 90% of circulars published on the dashboard within 24 hrs of issue |
| Searchable, current member directory | 80% of active members with verified profile by end of Month 3 |
| Reduce administrative load on office staff | Manual circular distribution effort down by ~60% |
| Institutional memory | All documents from the last 3 years digitised and indexed |

### 1.4 Non-goals (v1)
- Case management, cause-list integration, or e-filing.
- Online payment of membership subscription (deferred to Phase 2).
- Native mobile applications (responsive web only).
- Public-facing marketing website (separate scope).

---

## 2. Users & Roles

| Role | Description | Core permissions |
|---|---|---|
| **Member** | Enrolled advocate of GHCBA | Read all published content; edit own profile; RSVP; download documents |
| **Committee Member** | Serving on a standing/sub-committee | Member permissions + view committee-restricted documents |
| **Office Bearer** | President, Vice-President, Secretary, Treasurer, etc. | Publish announcements, events, newsletters; approve directory changes |
| **Admin / Office Staff** | Association secretariat | Full content CRUD, member onboarding, document library management |
| **Super Admin** | Kaizen / designated IT custodian | Role assignment, audit logs, system configuration |

### 2.1 Access control principles
- Every module is permission-gated; content items carry a visibility flag: `All Members`, `Committee Only`, or `Office Bearers Only`.
- Directory contact details respect per-member privacy toggles.
- All publish/delete actions are written to an immutable audit log.

---

## 3. Functional Requirements

### 3.1 Dashboard Home
The landing surface after login. Purpose: answer "what do I need to know today?" in one screen.

**Requirements**
- Greeting strip with member name, enrolment number, and membership status badge.
- Widget grid, reorderable is out of scope for v1 but layout must be config-driven:
  - **Latest Announcements** — 3 most recent, pinned items first.
  - **Today & This Week** — calendar entries for the next 7 days.
  - **Upcoming Events** — next 3 events with RSVP state.
  - **Recently Added Documents** — last 5 uploads.
  - **Current Newsletter** — cover card linking to the latest issue.
  - **Quick Links** — Directory search, Contact, Committee.
- Unread indicator on announcements since last login.
- Empty states for every widget with a meaningful message, never a blank card.

**Acceptance criteria**
- Home renders complete in under 2s on a 3G connection with cached shell.
- All widget data loads independently; one failing widget does not block the page.

---

### 3.2 Member Directory

**Requirements**
- Searchable, filterable list of all members.
- Search across: name, enrolment number, practice area, chamber location.
- Filters: enrolment year range, practice area, designation (Senior Advocate / Advocate / Advocate-on-Record), committee membership, membership status.
- Sort: name (A–Z), enrolment year, recently joined.
- List and card view toggle; list view is default on desktop, card on mobile.
- **Member profile page** fields:
  - Photograph, full name, enrolment number, date of enrolment
  - Designation, primary practice areas (multi-select tags)
  - Chamber address, chamber phone, mobile, email
  - Membership status (Active / Life / Suspended / Retired / Deceased)
  - Committee positions held (current and past)
  - Short professional bio (optional, 500 char)
- **Self-service editing**: a member may edit contact details, bio, practice areas, and photo. Changes to name, enrolment number, and designation require Admin approval and enter a moderation queue.
- **Privacy toggles**: member can hide mobile number and/or email from other members; office bearers always see full details.
- Bulk import of members via CSV/Excel at onboarding, with validation report and dry-run preview.
- Export directory to PDF (Admin only) for printed annual publication.

**Acceptance criteria**
- Search returns results within 500ms for a 2,000-member dataset.
- A pending profile change is visible to the member as "Awaiting approval" with the submitted value shown.

---

### 3.3 Announcements / Notices

**Requirements**
- Chronological feed, newest first, with pinning for high-priority notices.
- Announcement fields: title, rich-text body, category, priority, visibility, publish date, optional expiry date, attachments (multiple).
- Categories: General, Court Notice, Condolence, Election, Welfare Scheme, Meeting Notice, Urgent.
- Priority levels: Normal, Important, Urgent — drives colour treatment and notification behaviour.
- Filter by category and date range; full-text search across title and body.
- Read receipts: system records which members have opened an announcement (visible to Admin in aggregate only).
- Notifications on publish: in-app bell, email, and optional WhatsApp/SMS for `Urgent` (integration in Phase 2 — v1 sends email + in-app).
- Draft → Review → Published workflow. Only Office Bearers and Admin may publish.
- Scheduled publishing at a future date/time.

**Acceptance criteria**
- An expired announcement disappears from the feed but remains searchable in the archive.
- Condolence notices render in a distinct, restrained visual treatment.

---

### 3.4 Calendar

**Requirements**
- Month / week / list views, with month as default.
- Entry types, colour-coded: Court Holiday, Association Meeting, GBM/EGM, Event, Election, Hearing-of-Interest, Other.
- Annual court holiday list importable via CSV at the start of each calendar year.
- Click an entry to open a detail drawer; if the entry is an event, link through to the Event page.
- Filter by entry type.
- Export to `.ics` — full calendar subscription feed per member, so entries appear in Google/Outlook calendars.
- Mobile: list view is default; month grid remains accessible.

**Acceptance criteria**
- The `.ics` feed URL is per-member, tokenised, and revocable.
- Holiday entries are visually distinct from meetings and events at a glance.

---

### 3.5 Upcoming Events

**Requirements**
- Card grid of forthcoming events, sorted by date; past events accessible via an "Archive" tab.
- Event fields: title, banner image, description, date & time (start/end), venue, organiser, event type, capacity, RSVP deadline, attachments.
- Event types: Seminar, CLE / Training, Cultural, Sports, Felicitation, AGM, Farewell, Other.
- **RSVP**: Attending / Not Attending / Maybe, editable until the deadline. Guest count field where the event permits accompanying persons.
- Capacity handling: once capacity is reached, further RSVPs join a waitlist with automatic promotion on cancellation.
- Attendee list visible to organisers; visible to members only if the organiser enables it.
- Post-event: gallery upload (images), outcome note, and downloadable participation certificate where applicable.
- Automatic reminder emails at T-7 days and T-1 day to members who RSVP'd Attending.

**Acceptance criteria**
- RSVP state changes reflect optimistically in the UI and reconcile on server confirmation.
- Organisers can export the attendee list to Excel.

---

### 3.6 Document Library

**Requirements**
- Folder-based hierarchy with a suggested default tree:
  - Constitution & Bye-Laws
  - Circulars & Notifications
  - Minutes of Meetings (by year)
  - Forms & Applications
  - Welfare Scheme
  - Election Records
  - Financial Statements
  - Newsletter Archive
  - Miscellaneous
- Document fields: title, description, category/folder, tags, version, upload date, uploader, visibility.
- Supported formats: PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, JPG/PNG. Max 25 MB per file.
- In-browser PDF preview; no forced download.
- Full-text search across title, description, and tags. (Search inside PDF content is Phase 2.)
- Versioning: uploading a replacement retains prior versions with rollback for Admin.
- Download counter per document, visible to Admin.
- Bulk upload via drag-and-drop with per-file progress.

**Acceptance criteria**
- A `Committee Only` document never appears in a general member's search results.
- Deleting a document soft-deletes it; Admin can restore within 30 days.

---

### 3.7 Newsletter

**Requirements**
- Issue-based archive: cover image, issue number, month/year, editorial note, PDF file, optional web-readable version.
- Grid of issues with the latest featured prominently.
- In-browser reader for the PDF with page navigation and download option.
- Admin: create issue, upload PDF, set publication date, publish/unpublish.
- On publication, notify all members via in-app and email.
- Optional "Call for contributions" banner with a submission form (title, abstract, file upload) routing to the editorial committee.

**Acceptance criteria**
- Archive is browsable by year and searchable by issue title.
- Newsletter PDFs are also indexed into the Document Library under "Newsletter Archive" automatically.

---

### 3.8 Bar Committee

**Requirements**
- **Office Bearers** section: photo, name, designation, term period, contact, short message. President's message rendered as a featured block.
- **Executive Committee**: member cards with designation and term.
- **Standing & Sub-Committees**: each committee is a page with name, mandate/terms of reference, convenor, members, formation date, and associated documents (minutes, reports).
- Historical view: past committees by term year, read-only.
- Committee pages link through to member profiles in the Directory.
- Admin can create a new committee term and roll over/edit membership; the outgoing term is archived, never deleted.

**Acceptance criteria**
- Changing a member's committee position updates both the Committee page and the member's Directory profile.
- A member removed from a committee immediately loses `Committee Only` document access.

---

### 3.9 Contact

**Requirements**
- Association office details: address, phone, email, office hours, map embed.
- Office bearer contact block (respecting privacy settings).
- Contact/enquiry form with categories: General Enquiry, Membership, Welfare Scheme, Grievance, Technical Support, Other. Fields: name, enrolment number (pre-filled), category, subject, message, optional attachment.
- Submissions create a ticket with a reference number, visible to the submitting member with status (Open / In Progress / Resolved).
- Admin inbox with assignment, internal notes, and status change; email notification to the member on status change.
- Grievance category is routed to a restricted queue visible only to designated office bearers.

**Acceptance criteria**
- Every submission generates an acknowledgement email with the reference number within 1 minute.
- Spam protection (rate limiting + honeypot) is applied to the form.

---

## 4. Cross-Cutting Requirements

### 4.1 Authentication & onboarding
- Login by enrolment number or registered mobile number + password.
- OTP-based first-time activation via registered mobile; forced password set on first login.
- Password reset via OTP.
- Session timeout after 30 days of inactivity; "remember this device" supported.
- Admin can deactivate a member account immediately (revokes all sessions).

### 4.2 Notifications
- In-app notification centre (bell) with read/unread state.
- Email notifications for: new announcement, event reminder, newsletter publication, ticket status change, profile change approval.
- Per-member notification preferences page with per-category email opt-out (Urgent announcements are non-optional).

### 4.3 Search
- Global search bar in the header, spanning Directory, Announcements, Documents, Events, and Newsletter.
- Results grouped by module with a "see all in [module]" affordance.

### 4.4 Non-functional requirements
| Area | Requirement |
|---|---|
| Performance | First contentful paint < 1.5s; interactive < 3s on mid-range Android over 4G |
| Availability | 99.5% monthly uptime |
| Scale | 3,000 member accounts, 300 concurrent sessions, 50 GB document storage in year 1 |
| Browsers | Last 2 versions of Chrome, Edge, Firefox, Safari; Android Chrome; iOS Safari |
| Responsive | Fully usable from 360px width upward |
| Accessibility | WCAG 2.1 AA target: keyboard navigation, focus states, 4.5:1 contrast, alt text |
| Security | HTTPS only, bcrypt/Argon2 password hashing, JWT with refresh rotation, OWASP Top 10 mitigations, rate limiting on auth endpoints |
| Backup | Nightly database backup, 30-day retention; document storage replicated |
| Audit | Immutable log of all create/update/delete actions with actor, timestamp, and IP |
| Data residency | All data hosted within India |

---

## 5. Technical Approach

### 5.1 Stack
| Layer | Technology |
|---|---|
| Frontend | React 18 + TypeScript + Vite |
| Routing / data | TanStack Router + TanStack Query |
| Styling | Tailwind CSS + shadcn/ui |
| Motion | Framer Motion (restrained — page transitions, drawer, list stagger) |
| Backend | .NET 8 Web API |
| Database | SQL Server |
| File storage | Server file system or blob storage, served via signed URLs |
| Auth | JWT access + refresh tokens; OTP via SMS gateway |
| Email | SMTP / transactional email provider |
| Hosting | Windows Server + IIS |

### 5.2 Core data entities
`Member`, `Role`, `Announcement`, `AnnouncementRead`, `CalendarEntry`, `Event`, `EventRSVP`, `Document`, `DocumentVersion`, `Folder`, `NewsletterIssue`, `Committee`, `CommitteeMember`, `CommitteeTerm`, `Ticket`, `TicketMessage`, `Notification`, `AuditLog`.

### 5.3 Design direction
- Institutional and restrained — this is a professional body, not a consumer product. Serif display face for headings paired with a clean sans for UI text.
- Palette anchored on a deep legal navy/maroon with a neutral warm-grey surface set; single accent used sparingly for actions.
- Dense, legible tables in the Directory; generous whitespace in reading contexts (announcements, newsletter).
- Dark mode is out of scope for v1.

---

## 6. Phasing

| Phase | Scope | Indicative duration |
|---|---|---|
| **Phase 1** | Auth & onboarding, Dashboard Home, Directory, Announcements, Contact | 5–6 weeks |
| **Phase 2** | Calendar, Events + RSVP, Document Library | 4–5 weeks |
| **Phase 3** | Newsletter, Bar Committee, Notifications & preferences, Global search | 3–4 weeks |
| **Phase 4** | Data migration, UAT, training, go-live | 2–3 weeks |

**Deferred to a later release:** online subscription payment, WhatsApp notification channel, cause-list integration, full-text search inside PDFs, native mobile apps, member-to-member messaging.

---

## 7. Migration & Rollout

- Member data collected via structured Excel template from the association office; validated and imported with a dry-run report.
- Historical documents digitised and filed into the folder tree before go-live.
- Soft launch to office bearers and committee members for 2 weeks before opening to all members.
- Training: one session for office staff (content management), one recorded walkthrough for members.
- Support: 60 days of post-launch defect support included.

---

## 8. Open Questions

1. Total member count and how membership status is currently maintained.
2. Is there an existing digital member register, or is bulk data entry required?
3. Which SMS gateway is available for OTP, and who bears the recurring cost?
4. Should the dashboard be entirely private, or is a limited public view of announcements/events required?
5. Who approves directory changes — Secretary's office or a designated committee?
6. Volume and format of historical documents to be migrated.
7. Is Assamese language support required alongside English?
8. Preferred hosting arrangement — association-owned server or Kaizen-managed.

---

## 9. Success Metrics (90 days post-launch)

| Metric | Target |
|---|---|
| Member activation rate | 70% of registered members logged in at least once |
| Weekly active members | 35% |
| Announcements published on platform | 90% of all circulars issued |
| Directory profile completion | 80% with verified contact details |
| Event RSVPs via platform | 60% of total attendees |
| Support tickets resolved within 72 hrs | 85% |
