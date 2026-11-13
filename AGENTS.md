# Repository Agent Instructions

## Mandatory project context

Before implementing, modifying, reviewing or refactoring any property maintenance functionality, read:

- `docs/MAINTENANCE_MANAGEMENT_SPEC.md`

That document is the product and engineering source of truth for the Property Maintenance Management feature. Follow its domain distinctions, existing-architecture guidance, security requirements, lifecycle rules, financial allocation rules and testing expectations.

## General repository rules

- Inspect the live code and database schema before proposing or making changes. Do not assume documentation perfectly reflects the current implementation.
- Prefer extending existing domain models and workflows over creating duplicates.
- Preserve existing data and API compatibility; use safe, reversible migrations.
- Respect organisation tenant isolation and property-level authorisation. Use the existing `TenantScoped`, `Auditable` and Pundit patterns.
- Reuse existing Party, Lease, Inspection, DamageAssessment and Document functionality.
- Keep maintenance classification (wear and tear, damage, preventative work, etc.) separate from financial responsibility (owner, tenant, shared, other or pending).
- Never automatically treat a tenant as liable based solely on a damage classification or a lease-informed suggestion.
- Preserve estimates, quotations, approvals, actual costs, payments and allocations as distinct financial facts.
- Add or update tests for every meaningful behaviour and security boundary.
- Do not introduce dependencies or architectural rewrites without a clear need.
- Before finishing, run relevant tests, type checks, linting and build commands where available, and report what was and was not run.

When a task conflicts with the maintenance specification, call out the conflict and ask for clarification rather than silently changing the agreed product behaviour.
