# Estate360 Owner Workspace

## Purpose

Provide an independent workspace for landlords, private property owners and institutional ownership representatives who are not employees or members of the organisation managing their properties.

A person may use the same global User identity in more than one workspace. Workspace access is relationship-based and independently authorized.

## Workspace boundaries

- **Management:** active OrganizationMembership plus the selected organisation context. Property-level assignments further restrict staff access.
- **Owner:** verified User-to-Party link through PartyAccount plus a current, verified PropertyOwnership record in the selected organisation. No OrganizationMembership is required.
- **Tenant:** verified User-to-Party link and TenantProfile plus an eligible active Lease. No OrganizationMembership is required.

A person may qualify for more than one workspace. The client must request the intended workspace at login; the server issues a workspace-specific token. An owner token cannot be used against management or tenant endpoints.

## Implemented owner foundation

- Login accepts `workspace: "owner"`.
- Owner login requires a verified email, a verified PartyAccount and at least one current, verified PropertyOwnership record.
- Organisation context may be supplied as `organization_id`. If the user has current verified ownership in more than one organisation, context is mandatory; the server never selects one arbitrarily.
- Owner tokens carry the selected organisation and owner workspace, and are subject to the existing 24-hour expiry and token revocation checks.
- `GET /api/v1/owner/dashboard` returns an allowlisted profile, portfolio counts and current verified ownership interests with basic property identity/address data.
- Owner dashboard records are scoped to the authenticated user, verified PartyAccount, selected organisation and active verified ownership dates.
- Owner access is separate from management endpoints. Existing management routes continue to require the management workspace.
- The `view_owner_portfolio` and `propose_lease_renewals` capabilities are recognised for verified owners at the property authorization layer.

## Not yet implemented

The initial dashboard is deliberately read-only. It does not expose lease financial terms, tenant identities, internal inspections, management notes, ownership transfer controls, documents, maintenance costs or unrestricted property records.

Future owner features require separate scoped endpoints and explicit capabilities, including:
- Lease summaries and owner-authorized renewal proposals.
- Income, expenses, arrears and owner statements with appropriate financial permissions.
- Maintenance oversight and approval workflows, without granting management authority.
- Owner-visible documents and photographs with explicit publication and download authorization.
- Multiple representatives or beneficial owners, delegation, and revocation of owner access.
- Owner notifications and audit history for owner-visible actions.

Do not allow owners to mutate legal ownership records through the owner workspace. Ownership creation, verification, transfer and closure remain controlled by the authorised management/legal process and must retain their audit trail.

## Security rules

- Never infer a User-to-Party relationship from matching email addresses.
- Never treat an unverified PartyAccount or unverified/expired ownership record as authority.
- Revalidate ownership on every authenticated request, not only at login.
- Require organisation context when a user owns properties in multiple organisations.
- Return only data needed by the owner workspace; do not serialize Active Record objects wholesale.
- Do not reuse management controllers or tenant serializers for owner requests.
- Keep ownership verification and legal record mutation outside the owner self-service API.
