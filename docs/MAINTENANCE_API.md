# Maintenance API

This document describes the property-scoped maintenance API in `/api/v1`. All routes require the normal authenticated API session. Property access is checked for every operation; reads require an active property assignment, and mutations require an active property manager assignment. IDs for linked records are resolved within the work order's property or organisation.

## Work orders

Base route: `/api/v1/properties/:property_id/maintenance_requests`

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/maintenance_requests` | List work orders. Optional filters: `status` (comma-separated), `priority`, `category`, `filter=overdue`, `from`, and `to` (ISO dates). |
| POST | `/maintenance_requests` | Create a work order. `reported_at`, initial responsibility review state, and reporter are set server-side. |
| GET | `/maintenance_requests/:id` | Show a work order. |
| PATCH | `/maintenance_requests/:id` | Update editable details and property-scoped associations. |
| POST | `/:id/assign` | Set or clear `assigned_to_id` and/or `contractor_id` in an `assignment` object. |
| POST | `/:id/acknowledge`, `/submit_for_approval`, `/start`, `/verify`, `/close` | Perform the corresponding lifecycle action. |
| POST | `/:id/approve` | Approve an awaiting work order with `approved_cost` and optional `comments`. |
| POST | `/:id/reject` | Reject an awaiting work order with a required `reason`. |
| POST | `/:id/schedule` | Set required `scheduled_on` and optional `target_completion_on`. |
| POST | `/:id/complete` | Record completion with optional `actual_cost` and `resolution_notes`. |
| POST | `/:id/cancel` | Cancel with a required `reason`. |
| POST | `/:id/dispute_responsibility` | Mark responsibility disputed with a required `rationale`. |

Creation and update accept a `maintenance_request` object with editable fields including `title`, `description`, `category`, `priority`, `classification`, `source_type`, `unit_id`, `room_id`, `lease_id`, `contractor_id`, inspection/damage-assessment source IDs, `assigned_to_id`, schedule dates, `estimated_cost`, `currency`, and `resolution_notes`. The server derives organisation, property, reporter, and report timestamp.

Lifecycle transitions are explicit; arbitrary status updates are not accepted. The `close` action retains the existing combined behavior: a resolved request can be closed directly, and if not already verified, the closing manager is recorded as verifier.

## Cost responsibility and financial records

| Method | Route | Purpose |
| --- | --- | --- |
| POST | `/:id/allocations` | Approve a reconciled allocation set. Body: `rationale` and `allocations` array. Each allocation accepts `responsible_party`, `allocated_amount`, optional `allocation_percentage`, `currency`, `party_id`, `lease_id`, and `property_ownership_id`. |
| POST | `/:id/financial_entries` | Preserve the legacy generic financial-entry operation. |
| POST | `/:id/quotes` | Record a quotation (`amount`, `currency`, `occurred_on`, optional `valid_until`, reference, notes, party). |
| POST | `/:id/invoices` | Record an invoice (`amount`, `currency`, `occurred_on`, optional `due_on`, `invoice_reference`, reference, notes, party). |
| POST | `/:id/payments` | Record a payment (`amount`, `currency`, `occurred_on`, required `invoice_id`, optional `status` (`pending` or `paid`), reference, notes, party). |
| POST | `/:id/payments/:payment_id/mark_paid` | Mark a pending payment paid while validating the linked invoice balance. |

Allocations require an approved work-order amount, must reconcile to that amount and use its currency. Tenant allocations require an identified tenant party; when a lease is supplied or linked to the work order, the tenant must match that lease. A classification or lease alone never creates an allocation. Revising an approved allocation requires first disputing responsibility.

Financial-entry responses include `id`, `entry_type`, `amount`, `currency`, `status`, `occurred_on`, `reference`, `notes`, subtype dates/references, `invoice_id`, decision metadata, `party_id`, and `recorded_by_id`.

## Documents

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/:id/documents` | List documents visible to an assigned property user. |
| POST | `/:id/documents` | Attach an allowed PDF, Word document, or image (maximum 10 MiB). Multipart fields: `file`, `document_type`, and optional `title` and `description`. |

Document responses contain `id`, title/type/description, content type, size, a time-limited `url`, uploader ID, and creation time. Uploads require manager access; storage keys are not returned.

## Recurring schedules

Base route: `/api/v1/properties/:property_id/maintenance_schedules`

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/maintenance_schedules` | List schedules. |
| POST | `/maintenance_schedules` | Create a schedule. |
| PATCH | `/maintenance_schedules/:id` | Update schedule details and associations. |
| POST | `/:id/pause`, `/resume`, `/complete` | Change schedule lifecycle state. |
| POST | `/:id/generate` | Manually generate due occurrences. |

Schedule create/update accepts title/details, category, priority, classification, suggested responsibility, frequency/interval fields, start/end/next-due dates, reminder days, generation mode, estimated cost/currency, and optional unit, room, assignee, and contractor IDs. One-time schedules may include `target_completion_on`, which must be on or after `next_due_on` and is copied to the generated work order. `automatic` occurrences start `open`; `proposed` occurrences start `awaiting_approval`. Recurring plans advance when occurrences are generated and remain active when a work order is completed; one-time plans become completed after their occurrence is generated. Generated work orders inherit the schedule's room, classification, and safe responsibility suggestion; pending/unsupported suggestions become `unknown`. Monthly and longer intervals remain anchored to the original `starts_on` day when shorter months clamp a date. Generation is protected against duplicate schedule occurrences, and retries return only newly created occurrences.

Schedule responses include the schedule ID and property/unit/room IDs, descriptive and classification fields, suggested responsibility, frequency/interval values, lifecycle and generation settings, due and target-completion dates, cost/currency, assignee, and contractor IDs.

The existing daily `GenerateDueMaintenanceSchedulesJob` also enqueues notifications through Solid Queue. It emails the assigned user and schedule creator before due dates according to `reminder_days`, sends one overdue notice for the currently pending schedule date, and sends one overdue notice per work-order target date to its assignee and reporter. Markers prevent repeat notices until the due date changes. Paused and completed schedules are not notified. Date-only scheduling follows Rails' configured application time zone (`APP_TIME_ZONE`, default `UTC`); no per-property time-zone setting exists yet. Production email delivery must be configured through the existing Action Mailer deployment settings.

## Work-order response

List, show, create, update, and lifecycle responses return a work-order object with these groups:

- Identity and location: `id`, `property_id`, `unit_id`, `room_id`, title, description, category, priority, status.
- Classification and responsibility: `classification`, `suggested_responsibility`, `responsibility_status`, `responsibility_notes`, responsibility reviewer/time, and approval/rejection/cancellation notes.
- Sources and assignments: source IDs/type, `maintenance_schedule_id`, `lease_id`, contractor, reporter, and assignee IDs.
- Lifecycle timestamps: report, acknowledgement, schedule, start, resolution, verification, and closure.
- Financial facts: estimated, approved, and actual costs; currency; approval actor/time.
- Nested `cost_allocations`, `financial_entries`, `documents`, and `audit_history`.

The portfolio response retains its existing top-level `maintenance` array and existing fields, adding classification, responsibility and review metadata, source, room/lease, lifecycle, cost, allocation, and financial-entry summary fields for each work order.

Validation errors return `422` with `errors` or `error`; missing required parameters return `400`; denied property operations return `403`; records outside the scoped property resolve as not found.
