# Tenant Self-Service Portal — Product & Engineering Specification

**Status:** Approved product requirement; implementation requires separate approval  
**Scope:** Tenant identity, invitation and activation, tenancy dashboard, property and document visibility, lease renewals, tenant maintenance requests and notifications  
**Related specification:** `docs/MAINTENANCE_MANAGEMENT_SPEC.md` remains authoritative for maintenance classification, work-order lifecycle, approvals, scheduling and financial records.

## 1. Product objective

Provide a secure tenant workspace alongside the existing management workspace for administrators, owners and authorised agents. The tenant experience is a distinct, server-authorized product surface; it is not the management dashboard with selected controls hidden.

Tenants may:

- Receive an invitation from an authorised owner, agent or administrator and activate their account securely.
- Set and change their own password.
- View their own profile, internal tenant reference, eligible tenancies, rented premises and approved property photographs.
- View lease status, dates, agreed lease terms and documents explicitly shared with them.
- Review, accept or reject lease renewal proposals.
- Submit maintenance requests with photographs/documents, track their status, and read published updates, scheduled visits and completion information.
- Receive relevant notifications.

Tenants must not access property valuations, ownership records, owner financial information, internal management notes, confidential inspection evidence, contractor financial details, maintenance cost allocations or internal approvals. They must not access another tenant, property, lease or document by changing an identifier.

The only financial terms included in tenant responses are the tenant's own agreed lease terms. Do not expose maintenance expenditure or tenant-payment data unless a separate product requirement explicitly approves it.

## 2. Existing architecture and constraints

Verify the live code and schema before implementation. The current foundations include:

- `User` is organisation-scoped and uses `has_secure_password`. Its email uniqueness is organisation-scoped, but login currently looks up email without an organisation context. Resolve ambiguity without silently authenticating the wrong account.
- `Party` is the organisation-scoped counterparty record. `Lease` references one tenant Party, property and unit; there is no User-to-Party link today.
- `PropertyAssignment` is the existing property access foundation. `PropertyOwnership` associates an owner Party with a property but does not link that Party to an account.
- `Document` and Active Storage support lease and maintenance evidence. Documents have no tenant visibility flag.
- The property currently stores a cover-photo URL; property photographs do not have per-photo tenant visibility controls.
- The tenant API, tenant profile, invitations, lease renewal workflow and persisted tenant notifications do not exist.
- The management portfolio contains management-only property, ownership, lease and maintenance data. It is not a tenant response contract.

`TenantScoped` validates an organisation association but is not automatic query scoping. Every tenant read and write must explicitly scope the current account, Party, eligible Lease and associated property/premises.

## 3. Domain and identity architecture

### 3.1 User and Party relationship

Keep credentials on `User` and counterparty identity on `Party`; never store passwords on Party. Add a verified identity link between the authenticated User and the tenant Party. The tenant profile must be organisation-scoped and contain:

- User and tenant Party references.
- Internal tenant reference (not a government identifier).
- Contact information, with email sourced from the verified account.
- Profile photograph using Active Storage.
- Account/profile lifecycle and audit information where required.

The association must not be inferred or created solely from matching email addresses. Invitations and administrative linking must identify the exact Party and lease, and linking must reject an already-conflicting account/profile.

Support an explicit account-to-Party relationship for owner authorization as well. A user must not gain owner authority merely because they share a name or email with an ownership Party. If multiple users can represent one Party or one User can represent multiple Parties, model those relationships explicitly rather than adding an ambiguous single foreign key.

Do not add government-identity fields by default. If a later approved requirement needs them, store them encrypted, return only masked values, restrict access and audit reads/changes.

### 3.2 Organisation context and authentication compatibility

For the initial release, accounts remain organisation-scoped. Add explicit organisation context to login and activation so credentials resolve against a single organisation. Preserve the existing login route and existing single-organisation users: a legacy login without context may succeed only when the email identifies exactly one eligible account; ambiguous matches must require organisation context and must never select an arbitrary record.

Continue using the existing secure password mechanism. Provide an authenticated password-change flow and a secure reset/activation flow; never email temporary passwords. Activation verifies email possession. Add rate limits and generic public responses to reduce credential stuffing and account enumeration. Token expiry and logout/revocation behavior must be explicit; do not claim a stateless bearer token is revoked when it is not.

## 4. Invitation and activation

An invitation is issued for an exact tenant Party and Lease. Property and premises scope are derived from that Lease and revalidated server-side.

The invitation record must include:

- Organisation, tenant Party, target email, exact Lease and property scope.
- Inviter and creation/audit timestamps.
- A high-entropy, single-use activation token digest; never persist the raw token.
- Expiry, delivery, acceptance and revocation timestamps.
- A lifecycle status such as `pending`, `accepted`, `revoked` or `expired`.

Only an authorized organisation administrator, verified owner or agent with the required property capability may invite. Enforce that authority against the current verified ownership or active property assignment and the selected lease at creation and again at acceptance. Do not trust browser-supplied organisation, property, unit or Party IDs.

Deliver the raw token only in an activation link. On activation, atomically verify the token digest, expiry, status, target email and intended Party/Lease; mark the invitation consumed; verify the email; create/link the User and tenant profile; and set the tenant's password. Repeated, expired, revoked or cross-organisation tokens must fail. Do not automatically merge an existing account or profile.

## 5. Roles and permission model

Represent permission as server-side capabilities, not a single client-provided role. Preserve current manager permissions while adding narrow new capabilities.

| Actor | Source of authority | Permitted tenant-related operations | Boundary |
|---|---|---|---|
| Platform administrator | Explicit platform-level grant, outside ordinary organisation membership | Platform support/administration as explicitly granted | No implicit access to tenant data; privileged reads and actions must be scoped and audited |
| Organisation administrator | Explicit role in the current organisation | Invite tenants, manage organisation-level account/role configuration, administer authorized lease workflows | Organisation boundary; no cross-organisation access |
| Property owner | Verified account-to-Party link and current verified ownership record | Invite tenants and initiate renewals for owned properties; other actions only when explicitly granted | Ownership percentage/property and effective dates; no access to unrelated properties |
| Property manager/agent | Active `PropertyAssignment` plus explicit capability | Invite and manage tenant workflows only for assigned properties and capabilities | Assignment dates and property; retain existing manager restrictions |
| Tenant | Verified tenant profile and eligible Lease relationship | Read own profile/tenancies, act on own renewal proposals and submit/read own maintenance requests | No management assignment; no access to other Parties, leases, properties or internal data |

Minimum role additions are an explicit organisation administrator capability, account-to-Party identity linking for tenants and owners, and explicit property capabilities for agent actions such as inviting tenants or proposing a renewal. Keep platform-administrator authority separate. A role addition must not weaken current property-manager authorization.

## 6. Tenant dashboard and response contract

Use a dedicated tenant endpoint and allowlisted serializer. Do not call or reshape the management portfolio endpoint in the browser.

Proposed dashboard shape:

```json
{
  "profile": {
    "first_name": "…",
    "last_name": "…",
    "profile_photo_url": "…",
    "tenant_reference": "…"
  },
  "tenancies": [
    {
      "status": "active",
      "property": {
        "name": "…",
        "description": "…",
        "address": {},
        "photos": []
      },
      "premises": {
        "unit": {},
        "room": null
      },
      "lease": {
        "id": "…",
        "status": "active",
        "start_date": "…",
        "end_date": "…",
        "agreed_rent": {},
        "shared_documents": []
      }
    }
  ],
  "maintenance_requests": [],
  "renewal_proposals": [],
  "notifications": []
}
```

This is a contract direction, not permission to serialize complete model objects. Each tenancy and nested resource must be independently authorized. Lease rent and terms are visible only for that tenant's own lease. Include request status, dates, published updates and completion information; exclude financial entries, allocations, internal approval details, audit history, management notes, owner data and other tenants' information.

Persist notifications for the dashboard with recipient, type, related authorized resource, created/read timestamps and safe display content. Email delivery may use existing Action Mailer/Active Job infrastructure. Do not treat email delivery alone as an in-app notification record.

## 7. Property information and photographs

Expose only tenancy-relevant property data: name/description, appropriate address fields, the rented unit/room, and explicitly approved property photographs. Do not expose valuations, ownership/transfer records, internal asset inventory, inspection findings or internal condition notes.

Add a property-photo record backed by Active Storage with explicit visibility, uploader, caption/order and audit metadata. Deliver images only after tenant-lease authorization and photo-visibility checks. Do not persist or return long-lived unrestricted URLs. Inspection photos and existing documents remain private unless explicitly published for the tenant.

Do not add a general amenities subsystem in the initial release unless existing schema supports the needed data or the first release has a defined requirement for it.

## 8. Lease renewal and extension workflow

Use a versioned proposal/amendment linked to the existing Lease. Record:

- Existing lease and tenant Party.
- Proposed start/end dates, rent/currency, terms and any other agreed changes.
- Attached proposed lease document.
- Creator, creation time, response expiry and lifecycle status.
- Tenant response, response actor and timestamp, and resulting accepted document/signature reference where available.

Only an authorized owner or organisation administrator may initiate a proposal; an agent requires an explicit property capability. Notify the tenant and make the proposal visible only to the tenant Party on that lease. A tenant may submit an extension request against their own eligible lease; that request is not a proposal and cannot change lease dates, rent or terms.

The tenant may review, accept or reject a proposal but cannot directly update authoritative Lease dates or financial terms. Acceptance must be a durable, auditable business event. Do not mutate historical lease terms silently: create an immutable accepted amendment/version or a successor Lease linked to the previous Lease. Keep the prior lease and its documents available as authorized history.

Electronic signature is a future integration point. Acceptance must not be described as a legal signature unless a separately approved signing mechanism provides that guarantee.

## 9. Tenant maintenance workflow

Tenant requests reuse `MaintenanceRequest`; do not create a parallel request/work-order subsystem.

1. Resolve the current tenant profile and eligible Lease on the server.
2. Derive organisation, property, unit/room and lease from that tenancy.
3. Accept only the request description, category, urgency/priority and supporting evidence.
4. Set `reported_by` to the authenticated tenant, `source_type=tenant_request`, status `open`, and responsibility to pending review/unknown as appropriate.
5. Reject supplied organisation/property/lease/reporting identities, status transitions, contractor assignments, estimates/approved/actual costs, approvals, allocations and internal notes.
6. Route the request to management for acknowledgement and triage using the existing lifecycle.

`open` means submitted and awaiting management review for this flow. It is not `awaiting_approval`, which concerns management work/expenditure authorization. Tenant submission never approves expenditure, authorizes contractor work, determines financial responsibility or creates a tenant charge.

Add a publishable maintenance update mechanism for management updates, scheduled visits and completion information. Keep internal notes and audit history separate and private. Tenant responses include only published updates and an allowlisted status/date projection. Tenant-uploaded documents/photos are attached to the request with appropriate visibility; tenant access to later management evidence requires explicit publication.

## 10. Documents and confidentiality

Reuse `Document` and Active Storage, but add an explicit tenant visibility/publication state and publisher/time where required. Visibility must be evaluated on every listing and download using the exact lease/request relationship. Never infer tenant visibility from a document's parent, filename or type.

Lease documents, property photographs and maintenance evidence default to private. Only explicitly shared lease documents and explicitly tenant-visible photographs/maintenance evidence are included. Use authorized short-lived delivery or an authenticated download endpoint; do not reveal storage keys or durable direct URLs. Internal inspection evidence, approvals, quotes, invoices, receipts, cost allocation records and management documents remain unavailable unless a separate explicit sharing rule is approved.

## 11. Maintenance financial architecture

The current implementation uses `MaintenanceQuote`, `MaintenanceInvoice` and `MaintenancePayment` STI subclasses in the shared `maintenance_financial_entries` table. `MaintenanceCostAllocation` is a separate model/table. This gives the quote, invoice and payment types distinct model behavior while preserving shared identifiers, document references and invoice/payment relationships.

**Recommendation:** retain STI for the initial tenant release. The portal does not require separate physical tables, and splitting the existing records would create unnecessary data migration and foreign-key risk. Reconsider only if subtype-specific storage, lifecycle or query requirements demonstrate a concrete benefit. Preserve existing IDs, documents, invoice references and audit history if a future split is approved.

Do not include maintenance financial entries, contractor cost details, approvals or allocations in tenant responses. Agreed rent and other approved lease terms remain available only in the tenant's own lease view.

## 12. Proposed API surface

All endpoints remain under `/api/v1` and require server-side authorization except the narrowly scoped activation and login actions.

**Account and invitations**

- `POST /tenant_invitations` under an authorized property/lease scope.
- `GET /tenant_invitations` and `POST /tenant_invitations/:id/revoke` for authorized managers/owners.
- `POST /tenant/activate` to consume the activation token and establish the password.
- Existing login with explicit organisation context; authenticated password-change and account recovery operations.

**Tenant workspace**

- `GET /tenant/dashboard` and `GET/PATCH /tenant/profile`.
- `GET /tenant/leases` and `GET /tenant/leases/:id`, with tenant-visible documents only.
- `POST /tenant/leases/:id/extension_requests` to request an extension without changing the lease.
- `GET /tenant/renewal_proposals`; `POST /tenant/renewal_proposals/:id/accept` or `/reject`.
- `GET/POST /tenant/maintenance_requests` and `GET /tenant/maintenance_requests/:id`.
- `POST /tenant/maintenance_requests/:id/documents` and `GET /tenant/maintenance_requests/:id/updates`, tenant-scoped and visibility-filtered.
- `GET /tenant/notifications` and a read/acknowledge action scoped to the current recipient.

**Management workspace**

- Authorized invitation management and lease renewal proposal creation/management.
- Publication actions for tenant-visible property photos, lease documents and maintenance updates.

Use tenant-specific serializers. Never return the management portfolio payload to tenant routes. Resolve IDs through the authenticated tenant profile and its eligible leases; return not-found for out-of-scope records to avoid confirming their existence.

## 13. Proposed model and association changes

The smallest likely additive model set is:

- `TenantProfile` (or equivalent verified identity link): organisation, User, tenant Party, internal reference, contact fields and profile-photo attachment.
- Invitation record: organisation, Party, Lease/property scope, target email, inviter, token digest, status and lifecycle timestamps.
- Explicit owner account-to-Party mapping and organisation-admin/property capabilities.
- Tenant lease-extension request records, distinct from management-authored renewal proposals.
- Versioned lease renewal proposal/amendment.
- Tenant-visible property-photo record with Active Storage attachment.
- Tenant-publishable maintenance update/activity record, separate from internal notes and audit logs.
- Persisted tenant notification record.
- Explicit tenant visibility/publication metadata on existing Documents.

The current Lease is linked to a Unit, not a Room, and supports one tenant Party. If room-level leases or multiple tenant Parties per lease are required, add an explicit premise/tenant association; do not overload invitation fields or infer shared-lease access.

All new tenant-owned records must be organisation-scoped, auditable where decisions or visibility change, indexed for their scoped queries, and protected by foreign keys/validations ensuring linked User, Party, Lease, property, unit, room and inviter belong to the same organisation and property.

## 14. Migration dependencies and risks

1. Resolve login organisation context and define identity-link cardinality before linking existing Users to Parties.
2. Add additive role/capability and identity-link/profile structures; do not auto-link existing accounts by email.
3. Add invitations only after the account-to-Party/Lease relationship is enforceable.
4. Add visibility metadata and authorized delivery before exposing any existing document or image.
5. Add renewal proposal and published-update/notification records before exposing those workflows.
6. Backfill no visibility as private; backfill no identity relationship by guesswork. Preserve existing maintenance/financial IDs and historical leases.

The earlier maintenance implementation has migrations/schema whose execution was not verified in the prior phase. Before tenant migrations, run and reconcile the existing migration chain and generated schema in a functioning Rails environment. Verify production queue schema/configuration before depending on background email or notifications. Use reversible additive migrations and test upgrade from representative existing data.

## 15. Security and test requirements

Test at minimum:

- Cross-organisation, cross-lease, cross-property, cross-unit and cross-room access denial.
- Duplicate email ambiguity and explicit organisation-context login; no arbitrary account selection.
- Invitation authorization for each actor, token digest handling, expiry, replay, revocation, race conditions and conflicting/existing accounts.
- User-to-Party linking, owner account mapping, active/verified ownership, active assignment and explicit agent capabilities.
- Ended, future, terminated and unrelated leases; tenant access limited to eligible tenancy and historical data policy.
- Property-photo visibility and authorized delivery; document visibility, download access and private-by-default behavior.
- No exposure of internal notes, full audit history, approval records, maintenance financial entries, allocations, property valuations, owner data or another tenant's identity.
- Tenant cannot set reporter, lease/property IDs, status, contractor, costs, approvals, allocations or responsibility.
- Maintenance requests remain open/pending review and do not authorize spending; published updates are visible while internal updates are not.
- Renewal acceptance/rejection authorization, expiry, durable response event and historical lease integrity.
- Notification recipient scoping and read-state isolation.
- Existing management API, lease, maintenance, document and schedule compatibility.

## 16. Recommended implementation sequence

1. Confirm account identity cardinality, organisation-context login, co-tenant/room-lease scope and renewal acceptance/signature semantics.
2. Update the canonical maintenance specification and this tenant specification before code changes.
3. Implement organisation/owner/agent capabilities and verified User-to-Party tenant identity, then invitation and activation.
4. Add tenant policies, safe dashboard/profile/property/lease/document APIs and authorized photo delivery.
5. Add versioned renewal proposals, acceptance events, notifications and published maintenance updates.
6. Add tenant maintenance submission/list/detail/document APIs by extending existing maintenance foundations.
7. Build the dedicated tenant workspace and management invitation/renewal controls.
8. Apply migrations, backfill conservatively, and run backend, frontend and security-boundary tests.

## 17. Compatibility and implementation guardrails

- Preserve the management workspace, existing APIs, jobs, maintenance models and financial records.
- Keep tenant API authorization and serializers separate from management portfolio access.
- Do not add tenants as property managers or grant them management assignments.
- Keep request classification separate from cost responsibility and preserve the existing financial lifecycle.
- Do not expose tenant-visible information merely because its parent property, lease or request is accessible.
- Read this specification and `docs/MAINTENANCE_MANAGEMENT_SPEC.md` for any work touching both tenant self-service and maintenance.
