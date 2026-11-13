# Property Maintenance Management — Product & Engineering Specification

**Status:** Product design baseline  
**Scope:** Property-level maintenance planning, work orders, scheduling, evidence, cost allocation and maintenance history  
**Primary implementation location:** Existing property workspace → Maintenance tab

This document is the source of truth for the intended Property Maintenance Management feature. Read it before designing, implementing, refactoring or reviewing maintenance-related functionality.

## 1. Product objective

Build a reliable property maintenance management capability that allows an organisation to plan, request, schedule, assign, approve, perform, evidence, cost and review maintenance work throughout a property's lifecycle.

The feature must answer:

1. What work is required?
2. Why is it required, and where is it required?
3. When is it due, scheduled, started and completed?
4. Who is responsible for performing and approving it?
5. What was estimated, approved, incurred and paid?
6. How is the cost allocated between the owner, tenant or other responsible parties?
7. Is the work normal wear and tear, damage, preventative maintenance, an improvement or another classification?
8. What evidence supports the work, completion and cost allocation?

This is a property asset-management capability, not merely a list of repair tickets.

## 2. Existing application foundations — inspect and reuse

The repository already contains relevant foundations. Verify their current implementation before changing anything:

- `MaintenanceRequest` is the existing maintenance record. It includes `TenantScoped` and `Auditable`, belongs to a property, optionally belongs to a unit and room, has a reporter and optional assigned user, and has associated documents.
- Existing `MaintenanceRequest` fields include title, description, category, priority, status, reported/acknowledged/resolved/closed timestamps, estimated cost, actual cost and resolution notes.
- Existing maintenance statuses include `open`, `acknowledged`, `in_progress`, `resolved`, `closed` and `cancelled`.
- `DamageAssessment` already captures a damage description, severity, responsibility (`landlord`, `tenant`, `shared`, `unknown`), estimated/agreed cost and resolution status.
- `Document` can already be associated with a `maintenance_request`, and document records are tenant-scoped.
- `Property` already has many `maintenance_requests` and `damage_assessments`.
- The application uses UUID primary keys, organisation-level tenant scoping, `TenantScoped`, `Auditable` and Pundit policies. Preserve these conventions.
- The frontend is React + TypeScript. The property portfolio response already exposes a maintenance collection, but inspect its full current shape and API loading path before changing it.

Do not create a duplicate maintenance request/work-order table if the existing model can be evolved safely. Do not duplicate damage-assessment, party, document, lease, inspection or audit functionality.

The README describes organisation as the tenant root and property assignments as object-level authorisation. Enforce both organisation boundaries and the user's property-level permissions.

## 3. User experience and navigation

Extend the existing **Maintenance** tab in the property detail workspace. Do not create a disconnected maintenance application.

The Maintenance workspace should provide:

- Overview/dashboard.
- Work orders.
- Calendar/schedule.
- Recurring maintenance plans.
- Maintenance history.
- Cost and responsibility summaries.

Provide useful filters for all, upcoming, overdue, awaiting approval, in progress, completed, cancelled and (where appropriate) disputed work.

Support list and calendar/timeline presentations. Make the interface responsive and consistent with the existing design system.

### 3.1 Dashboard

Show property-level indicators where data is available:

- Total work orders.
- Open/overdue work orders.
- Upcoming scheduled work.
- Work in progress.
- Completed work over a selected period.
- Estimated, approved and actual maintenance expenditure.
- Amount paid and outstanding.
- Owner-attributed and tenant-attributed costs.
- Next scheduled maintenance due.

Never fabricate missing data. Clearly distinguish estimates from actuals and paid amounts. Do not aggregate different currencies without a valid conversion mechanism.

### 3.2 Work-order details

Each work order should support:

- Title and detailed description.
- Maintenance category and optional subcategory.
- Property, building/unit/room or specific asset/location.
- Priority and reason/source.
- Reported/requested date.
- Planned start, scheduled date and target completion date.
- Actual start and completion dates.
- Status and status history.
- Reporter/requester.
- Assigned internal user.
- External contractor/service provider, where supported by the existing Party model.
- Linked tenant and active/relevant lease, where applicable.
- Linked inspection or inspection finding, where applicable.
- Wear-and-tear/damage/maintenance classification.
- Cost responsibility and detailed allocations.
- Estimates, quotations, approvals, invoices, receipts and payment details.
- Before/after photographs, completion report and notes.
- Cancellation, rejection or dispute reason.
- Audit trail.

Use existing property, unit, room, party, lease, inspection, document and user records wherever possible.

### 3.3 Maintenance categories

Support configurable or consistently managed categories, including at least:

- Painting and decorating.
- General repairs.
- Plumbing and drainage.
- Electrical work.
- Installations and replacements.
- Roofing and waterproofing.
- Structural repairs.
- Fumigation and pest control.
- Tree felling, pruning and landscaping.
- Cleaning and grounds maintenance.
- HVAC and air conditioning.
- Generator, pump and equipment servicing.
- Security systems.
- Inspections and compliance-related maintenance.
- Preventative maintenance.
- Improvements/upgrades.
- Other.

Avoid hard-coding category logic throughout the application. Use the repository's existing enum/configuration conventions or introduce a maintainable category mechanism.

## 4. Maintenance classification is separate from cost responsibility

This is a mandatory domain distinction.

### 4.1 Classification

A work order should classify the reason/nature of the work. Include values such as:

- Normal wear and tear.
- Accidental damage.
- Negligence.
- Misuse.
- Structural deterioration.
- Preventative maintenance.
- Breakdown/failure.
- Improvement/upgrade.
- Compliance/safety requirement.
- Other.
- Undetermined/not yet assessed.

Do not assume that a classification alone proves liability.

### 4.2 Financial responsibility

Record responsibility independently of classification:

- Owner/landlord.
- Tenant.
- Shared.
- Organisation/property manager, if the business rules require it.
- Third party/contractor/insurer, if supported.
- Undetermined/pending review.

For shared responsibility, store explicit allocations per responsible party, using either amounts or percentages with clear validation. The sum of allocations must reconcile to the amount being allocated, subject to the chosen rounding rules.

Do not infer tenant liability merely because a job is classified as damage. Do not infer owner liability merely because a job is classified as wear and tear. Responsibility must be reviewed and approved by an authorised user, considering the lease, evidence and applicable law.

Where an active lease exists, lease responsibility terms may inform a suggested/default allocation, but must not silently create a charge or override a human decision. Keep the decision, rationale, actor and timestamp auditable.

Support unknown, disputed and pending-review responsibility states. Do not force a premature allocation.

## 5. Financial model

Keep the following financial concepts separate:

- Initial estimate.
- Quoted amount.
- Approved amount.
- Actual final cost.
- Amount invoiced.
- Amount paid.
- Outstanding balance.
- Owner allocation.
- Tenant allocation.
- Other-party allocation.
- Currency.

The existing `estimated_cost` and `actual_cost` fields should be preserved and evolved compatibly. Determine whether quotation, approval, invoice and payment data merit separate records or a coherent expense/financial detail model. Do not overload one decimal field to represent several financial states.

Use suitable decimal precision, preserve original currency on every monetary record, and validate non-negative values unless a documented use case requires otherwise.

A zero or not-applicable transfer/service price must be allowed where appropriate; not every job is a sale or a chargeable tenant expense.

For shared allocation:
- Store the responsible party and allocated amount or percentage.
- Validate totals against the relevant cost basis.
- Handle decimal rounding explicitly.
- Preserve allocation history if an approved allocation is later corrected.
- Record who approved or changed the allocation and why.

Do not implement rent invoicing, tenant debt collection or accounting ledger behaviour as an accidental side effect of maintenance allocation. Those integrations require explicit domain design.

## 6. Scheduling and recurring maintenance

Keep a maintenance plan/schedule concept distinct from an individual work order.

A schedule describes recurring or planned work. A work order records one actual instance of work.

Schedules should support:

- Property and optional unit/asset/location.
- Category and description.
- Start date and optional end date.
- Frequency/interval (for example monthly, quarterly, every six months, annually, or a custom interval).
- Next due date.
- Reminder lead time.
- Default priority.
- Default service provider/assignee.
- Indicative budget/default estimate and currency.
- Suggested cost responsibility and classification.
- Active/paused/completed schedule status.
- Generation mode.

Generation modes should be configurable:
1. Automatically generate a work order when due.
2. Generate a proposed work order that requires approval.
3. Send a reminder only and let a user create the work order.

Completing one occurrence must not delete or mutate the recurring plan. It should calculate/preserve the next due date and create or propose the next occurrence according to the configured mode. Avoid duplicate generation if a job is retried.

Support one-time scheduled work as well as recurring plans. Handle time zones and date boundaries consistently with the application.

## 7. Work-order lifecycle and approvals

The current application already has maintenance statuses. Extend them deliberately and compatibly rather than casually replacing existing values.

The intended business lifecycle is:

1. Requested/open.
2. Acknowledged / triaged.
3. Awaiting approval, where required.
4. Approved.
5. Scheduled.
6. In progress.
7. Work reported complete / resolved.
8. Verified and closed.

Also support rejected, disputed and cancelled outcomes where appropriate.

Map this lifecycle to the existing status model in a documented way. Do not create invalid or ambiguous status transitions.

Approval rules should be configurable. The product should support:
- Manager approval within delegated budget/authority.
- Owner approval above a configurable threshold or where policy requires it.
- Explicit approval for tenant-attributed charges.
- Recording approver, decision, timestamp, amount approved and comments/reason.

Do not assume that every job needs the same approval route. Do not allow an unapproved estimate or tenant allocation to be treated as an authorised charge.

A completed work order should remain in the history. Closing/reopening/cancelling should be controlled and audited.

## 8. Service providers and assignments

Distinguish internal responsibility from the external service provider:

- Reporter/requester.
- Internal assignee or property manager.
- Contractor/service provider.
- Approver.
- Person who verifies completion.

Reuse the existing `Party` model if it supports contractor/service-provider party types. Do not create a duplicate contact system.

Capture provider contact details through the existing party/contact architecture. Work orders should support quotation and invoice documents and a record of who performed the work.

## 9. Inspection and damage integration

Maintenance should connect naturally to the existing inspection/sn aglist and damage-assessment workflows.

- An inspection finding should be able to create a maintenance work order without re-entering the same description, property/unit/room/item context and relevant evidence.
- Preserve the source inspection and finding references.
- A damage assessment may inform the work order's classification and proposed responsibility, but does not automatically prove final liability.
- Record whether a work order originated from a tenant request, routine schedule, inspection, damage assessment, manager or other source.
- Avoid duplicate work orders when the same finding is actioned more than once.

The maintenance record must remain independently understandable even if the source inspection is later archived.

## 10. Evidence and documents

Reuse the existing `Document` architecture and its `maintenance_request_id` association.

Support document types such as:
- Quotation.
- Approval.
- Work order/instruction.
- Before photograph.
- After photograph.
- Invoice.
- Receipt/payment proof.
- Completion report.
- Compliance certificate.
- Other.

Use existing upload/storage/security patterns. Enforce tenant and property access on upload and download. Do not expose storage keys or unrestricted document URLs.

Preserve evidence and audit history when a job is closed.

## 11. Data model direction

Treat this as conceptual guidance, not an instruction to create every named table. Inspect the live schema and choose the smallest coherent design.

Likely concepts:

- Existing `MaintenanceRequest` (evolve as the canonical work-order record; consider whether the UI should label it a work order without forcing a risky table rename).
- `MaintenanceSchedule` (recurring/planned maintenance plan).
- `MaintenanceCostAllocation` (owner/tenant/shared/other party allocation, if not better represented by a well-designed existing model).
- Quote/expense/payment detail records only if required to keep financial states accurate.
- Existing `DamageAssessment` remains the assessment domain.
- Existing `Document` remains the evidence domain.

Potential fields to evaluate for the work-order record include scheduled date, target completion, actual start/completion, classification, responsibility/review status, lease/tenant references, contractor reference, source inspection/damage assessment references, approval metadata and currency.

Use UUIDs, foreign keys, indexes and check constraints consistent with the repository. All new records must carry the organisation/tenant key and use `TenantScoped`/existing tenant enforcement. Ensure associated property, unit, room, lease, party, user and source records belong to the same organisation and relevant property.

Do not add a field or table simply because it appears in this document. First inspect existing schema and model relationships, then explain and implement the appropriate design.

## 12. Security, permissions and auditability

Every operation must enforce:
- Organisation/tenant isolation.
- Property-level assignment/authorisation.
- Pundit policy checks or the established authorisation pattern.
- Same-organisation validation for linked users, parties, contractors, leases, units, rooms, inspections, damage assessments and documents.
- Secure document access.
- Role/authority checks for approvals, cost allocations and verification.

Never trust an organisation ID or ownership/tenant relationship supplied by the browser. Derive and validate it server-side.

Use the existing `TenantScoped` and `Auditable` concerns. Audit meaningful changes to schedule, assignment, status, classification, responsibility, estimate, approved amount, actual cost, payment state, documents and verification. Do not permit silent destructive edits to historical financial or approval data.

## 13. API and frontend expectations

Follow existing Rails API versioning, response conventions, authentication and Pundit policies.

Provide the necessary operations to:
- List/filter work orders for a property.
- Show work-order details.
- Create/update a work order.
- Perform valid lifecycle transitions.
- Approve/reject work and allocations.
- Record completion and verify/close work.
- Manage recurring schedules and generated occurrences.
- Manage cost allocations and financial details.
- Attach/list documents.
- Link an inspection finding or damage assessment.

Update React/TypeScript types to match the real API payload. Do not hard-code sample work orders or financial totals in production UI.

Include loading, empty, error and success states; accessible forms; client-side convenience validation backed by server validation; confirmation for consequential actions; responsive layouts; and clear distinction between estimates, approvals, actuals and payments.

## 14. Reporting and maintenance intelligence

Provide property-level and portfolio-level reporting when the underlying data supports it:

- Spend by property, category, period and provider.
- Owner/tenant/other responsibility totals.
- Estimated versus actual variance.
- Upcoming and overdue maintenance.
- Repeat faults and recurring repairs.
- Maintenance history by property, unit, room or asset.
- Equipment/service history.
- Work-order completion time.

Do not calculate cross-currency totals without an explicit exchange-rate source and conversion date. Flag repeated failures as indicators for review, not as automatic conclusions that replacement is required.

## 15. Testing requirements

Add backend and frontend tests for at least:

- Creating, updating and viewing work orders.
- Existing maintenance request compatibility.
- Valid and invalid lifecycle transitions.
- Scheduled and overdue work.
- Recurring plan generation and duplicate prevention.
- Tenant isolation and property assignment authorisation.
- Cross-organisation association rejection.
- Classification independent from responsibility.
- Unknown/disputed responsibility.
- Owner, tenant and shared allocations.
- Allocation reconciliation and rounding.
- Estimate, quote, approved amount, actual cost and payment distinctions.
- Different currencies and prevention of invalid aggregation.
- Approval thresholds and approval permissions.
- Lease-informed suggestions without automatic tenant charging.
- Inspection/damage assessment linkage.
- Document access control.
- Audit history.
- Completed, cancelled and historical records remaining visible.

Run the relevant test suites, frontend type checking, linting and build. Fix regressions introduced by the work.

## 16. Implementation approach

Work in controlled stages:

1. **Assessment:** inspect the live models, schema, controllers, routes, policies, serializers, frontend, tests and document workflow. Report gaps and propose the smallest coherent design.
2. **Domain/data:** extend the existing maintenance foundation, add only necessary migrations/models/constraints/indexes, and preserve existing data/API behaviour.
3. **Backend:** implement validations, tenant/property security, lifecycle services, schedule generation, approval, allocation and document integration.
4. **Frontend:** implement the dashboard, work-order list/detail/form, schedule/calendar and maintenance history in the existing property workspace.
5. **Integration:** connect inspections, damage assessments, leases and parties without duplicating their responsibilities.
6. **Verification:** run tests, type checks, lint/build and security-focused checks. Summarise migrations, endpoints, files, tests and known limitations.

Do not stop at a plan when asked to implement. However, do not make irreversible schema or business-rule assumptions where important decisions remain open; surface those decisions clearly.

## 17. Decisions that remain configurable or require product confirmation

Do not silently assume these values:
- Whether tenant cost defaults are derived from lease clauses, configurable category rules or manual review. A lease may inform a suggestion, but approval and applicable law govern the final allocation.
- Approval thresholds and who can approve which amounts.
- Whether recurring work auto-generates, requires approval or only sends reminders.
- Which evidence is mandatory for each work category or cost responsibility.
- Which contractor fields and service-provider party types are already supported.
- Whether tenant-facing maintenance request submission is in scope for the first release.

Implement sensible, configurable foundations and document any unresolved choices.

## 18. Definition of done

The feature is ready when a property manager can plan a one-time or recurring job, create and assign a work order, record its classification, review and approve who bears the cost, track estimates through actual payment, attach evidence, record completion, and retrieve the full history later.

The solution must preserve existing maintenance and damage-assessment data, respect tenant/property security, and integrate naturally into the existing property workspace.

**Engineering principle:** Build a maintainable property asset lifecycle capability with trustworthy records. Data integrity, traceability, security and clear financial responsibility take precedence over visual polish or premature automation.
