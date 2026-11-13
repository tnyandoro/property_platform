# Copilot Instructions

For all work involving property maintenance, maintenance requests/work orders, recurring maintenance, scheduling, contractors, damage assessments, wear and tear, owner/tenant cost allocation, maintenance expenses, invoices, maintenance documents, or maintenance reporting:

1. Read `docs/MAINTENANCE_MANAGEMENT_SPEC.md` before making changes. It is the canonical product and engineering specification.
2. Read the root `AGENTS.md` for repository-wide agent rules.
3. Inspect the current Rails models, migrations/schema, controllers, routes, Pundit policies, serializers, React/TypeScript components and tests before designing changes.
4. Extend the existing `MaintenanceRequest`, `DamageAssessment` and `Document` foundations where appropriate. Do not create duplicate subsystems.
5. Keep work classification (including normal wear and tear) distinct from who is financially responsible. A classification or lease-derived suggestion must not silently create tenant liability.
6. Preserve organisation and property-level security, auditability, historical records and the distinction between estimates, approved amounts, actual costs and payments.
7. Implement and test backend and frontend changes consistently. Report migrations, API changes, tests and remaining decisions.

If a task appears to conflict with the specification, explain the conflict and ask for clarification instead of silently overriding the documented design.
