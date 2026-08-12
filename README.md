# Property lifecycle platform — schema notes

Four migrations, in build order:

1. `001_foundation.rb` — organizations (tenant boundary), users, parties, property_assignments
2. `002_property_registry.rb` — properties, ownership history, buildings, units, rooms, items
3. `003_inspection_engine.rb` — inspections, immutable inspection_items, amendments, photos
4. `004_leasing_and_maintenance.rb` — leases, maintenance, damage assessments, documents, audit_logs

## Key decisions baked into this schema

- **Organization is the tenant root.** Every table carries `organization_id`. Enforce this at the query layer with a gem like `acts_as_tenant` or Postgres row-level security — don't rely on controllers remembering to scope.
- **No `owner_id` column on `properties`.** Current owner is derived: `PropertyOwnership.where(property_id: x, end_date: nil)`. Add a cached column later only if profiling shows you need it — never treat it as the source of truth.
- **Bedrooms/bathrooms live on `units`, not `properties`.** Properties get denormalized rollups (`cached_total_units`, `cached_total_bedrooms`) refreshed via an `after_commit` callback on `units`, for dashboard/search speed.
- **Inspections are append-only snapshots.** `inspection_items` rows are never updated once `inspections.locked_at` is set. Corrections go into `inspection_amendments`. This makes move-in vs move-out comparison a plain join on `property_item_id` across two inspections, not a diff against mutable state.
- **`condition` is both an enum and a `condition_score` integer (1–5).** The label is for humans; the score is what you sort, average, and diff on.
- **Photos attach via two nullable FKs, not a polymorphic association**, so foreign key constraints stay real. A check constraint enforces at least one is set.
- **`property_assignments` gives object-level authorization** (which agent can touch which property), which a flat `role` enum on `users` can't express. Pair this with Pundit/CanCanCan policies scoped by `organization_id + property_assignments`.

## Suggested next steps

- Add `acts_as_tenant`-style default scoping before writing any controllers.
- Wire `audit_logs` writes via a model concern (e.g. `Auditable`) triggered in `after_save`/`after_destroy`, not manually in each controller action.
- Photo uploads: use `has_one_attached`/`has_many_attached` with Active Storage pointed at S3, or issue presigned URLs directly from an API endpoint if you want true direct-to-S3 upload from the mobile inspection flow.
