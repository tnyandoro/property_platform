# Tenant Maintenance Requests API

**Status:** Implemented initial text-only tenant request API  
**Authentication:** Signed access token with `workspace=tenant`; the authenticated user must have a verified email and a verified tenant profile in the token's organisation.

All routes are under `/api/v1`.

## Endpoints

- `GET /tenant/maintenance_requests` — list requests reported by the authenticated tenant against their currently eligible leases.
- `POST /tenant/maintenance_requests` — submit a request for one of the tenant's eligible leases.
- `GET /tenant/maintenance_requests/:maintenance_request_id` — show one of the authenticated tenant's own requests.

## Create request

Example:

```http
POST /api/v1/tenant/maintenance_requests
Authorization: Bearer <tenant-access-token>
Content-Type: application/json
```

```json
{
  "maintenance_request": {
    "lease_id": "eligible-lease-uuid",
    "description": "The kitchen tap is leaking under the sink.",
    "category": "plumbing",
    "priority": "high"
  }
}
```

The `lease_id` selects a tenancy; it is not trusted as proof of access. The server resolves it through the authenticated tenant's verified PartyAccount/TenantProfile and checks that the lease is active and current, and that its property and unit belong to the same organisation and property.

The server derives organisation, property, unit, lease, and reporter. The request is always created with:

- `source_type=tenant_request`
- `status=open` (projected to `submitted` in tenant responses)
- `classification=undetermined`
- `suggested_responsibility=unknown`
- `responsibility_status=pending_review`
- no assignment, approval, schedule, estimate, actual cost, allocation, or internal management notes.

The title is generated from the submitted description. The server accepts only `lease_id`, `description`, `category` and `priority` from the nested request payload. Attempts to submit organisation/property/unit/room/reporter identities, status, source, responsibility, assignment, approval or financial fields are rejected with `422 Unprocessable Entity`. Missing description/lease selection and descriptions over 10,000 characters are rejected.

Out-of-scope, expired, future, or otherwise ineligible leases and requests belonging to another tenant return `404 Not Found` so the API does not confirm another tenant's records.

## Response visibility

Responses use a tenant-specific allowlist: request ID, lease ID, title, description, category, priority, projected status, submitted timestamp, and published updates only. Draft/internal updates, management audit data, contractor details, estimates, approvals, financial entries and cost allocations are not serialized.

## Current limitations

- This initial endpoint is text-only. Tenant-uploaded photographs/documents and authenticated evidence delivery are not included yet; they require the explicit visibility and publication workflow in the tenant self-service specification.
- A tenant account with multiple verified tenant profiles in the same organisation is treated as ambiguous and receives `404` until the account-to-party context is explicitly resolved.
- Submission creates a request for management triage. It does not approve expenditure, authorise contractor work, determine financial responsibility or create a tenant charge.
