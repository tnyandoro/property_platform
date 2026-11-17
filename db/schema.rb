# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_13_144000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.uuid "auditable_id", null: false
    t.string "auditable_type", null: false
    t.jsonb "changes_payload", default: {}
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "occurred_at", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["occurred_at"], name: "index_audit_logs_on_occurred_at"
    t.index ["organization_id", "actor_id"], name: "index_audit_logs_on_organization_id_and_actor_id"
    t.index ["organization_id", "auditable_type", "auditable_id"], name: "idx_audit_logs_on_org_auditable"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.check_constraint "action::text = ANY (ARRAY['create'::character varying, 'update'::character varying, 'destroy'::character varying, 'lock'::character varying, 'unlock'::character varying]::text[])", name: "audit_logs_action_check"
  end

  create_table "buildings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "building_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "property_id"], name: "index_buildings_on_organization_id_and_property_id"
    t.index ["organization_id"], name: "index_buildings_on_organization_id"
    t.index ["property_id"], name: "index_buildings_on_property_id"
  end

  create_table "damage_assessments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "agreed_cost", precision: 12, scale: 2
    t.uuid "assessed_by_id", null: false
    t.date "assessed_on", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.uuid "inspection_id"
    t.uuid "inspection_item_id"
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.text "resolution_notes"
    t.string "responsibility", default: "unknown", null: false
    t.string "severity", default: "minor", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["assessed_by_id"], name: "index_damage_assessments_on_assessed_by_id"
    t.index ["inspection_id"], name: "index_damage_assessments_on_inspection_id"
    t.index ["inspection_item_id"], name: "index_damage_assessments_on_inspection_item_id"
    t.index ["organization_id", "property_id"], name: "index_damage_assessments_on_organization_id_and_property_id"
    t.index ["organization_id", "status"], name: "index_damage_assessments_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_damage_assessments_on_organization_id"
    t.index ["property_id"], name: "index_damage_assessments_on_property_id"
    t.check_constraint "responsibility::text = ANY (ARRAY['landlord'::character varying, 'tenant'::character varying, 'shared'::character varying, 'unknown'::character varying]::text[])", name: "damage_assessments_responsibility_check"
    t.check_constraint "severity::text = ANY (ARRAY['minor'::character varying, 'moderate'::character varying, 'severe'::character varying, 'critical'::character varying]::text[])", name: "damage_assessments_severity_check"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'under_review'::character varying, 'agreed'::character varying, 'disputed'::character varying, 'resolved'::character varying, 'written_off'::character varying]::text[])", name: "damage_assessments_status_check"
  end

  create_table "documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.uuid "damage_assessment_id"
    t.text "description"
    t.string "document_type", null: false
    t.integer "file_size_bytes"
    t.uuid "inspection_id"
    t.uuid "lease_id"
    t.uuid "maintenance_financial_entry_id"
    t.uuid "maintenance_request_id"
    t.uuid "organization_id", null: false
    t.uuid "property_id"
    t.uuid "property_ownership_id"
    t.datetime "published_at"
    t.uuid "published_by_id"
    t.string "storage_key", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "uploaded_by_id", null: false
    t.string "visibility", default: "internal", null: false
    t.index ["maintenance_financial_entry_id"], name: "index_documents_on_maintenance_financial_entry_id"
    t.index ["maintenance_request_id"], name: "index_documents_on_maintenance_request_id"
    t.index ["organization_id", "document_type"], name: "index_documents_on_organization_id_and_document_type"
    t.index ["organization_id", "inspection_id"], name: "index_documents_on_organization_id_and_inspection_id"
    t.index ["organization_id", "lease_id"], name: "index_documents_on_organization_id_and_lease_id"
    t.index ["organization_id", "property_id"], name: "index_documents_on_organization_id_and_property_id"
    t.index ["organization_id", "property_ownership_id"], name: "index_documents_on_org_and_property_ownership"
    t.index ["organization_id"], name: "index_documents_on_organization_id"
    t.index ["property_ownership_id"], name: "index_documents_on_property_ownership_id"
    t.index ["published_by_id"], name: "index_documents_on_published_by_id"
    t.index ["uploaded_by_id"], name: "index_documents_on_uploaded_by_id"
    t.check_constraint "property_id IS NOT NULL OR lease_id IS NOT NULL OR inspection_id IS NOT NULL OR maintenance_request_id IS NOT NULL OR maintenance_financial_entry_id IS NOT NULL OR damage_assessment_id IS NOT NULL OR property_ownership_id IS NOT NULL", name: "documents_must_have_parent"
    t.check_constraint "visibility::text <> 'tenant_visible'::text OR published_at IS NOT NULL AND published_by_id IS NOT NULL", name: "documents_publication_metadata_check"
    t.check_constraint "visibility::text = ANY (ARRAY['internal'::character varying, 'tenant_visible'::character varying]::text[])", name: "documents_visibility_check"
  end

  create_table "inspection_amendments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "amended_by_id", null: false
    t.text "amended_value", null: false
    t.datetime "created_at", null: false
    t.string "field_name", null: false
    t.uuid "inspection_id", null: false
    t.uuid "inspection_item_id", null: false
    t.uuid "organization_id", null: false
    t.text "original_value"
    t.text "reason"
    t.index ["amended_by_id"], name: "index_inspection_amendments_on_amended_by_id"
    t.index ["inspection_id"], name: "index_inspection_amendments_on_inspection_id"
    t.index ["inspection_item_id"], name: "index_inspection_amendments_on_inspection_item_id"
    t.index ["organization_id", "inspection_id"], name: "idx_on_organization_id_inspection_id_455883dfcc"
    t.index ["organization_id", "inspection_item_id"], name: "idx_on_organization_id_inspection_item_id_7a7c08c8f1"
    t.index ["organization_id"], name: "index_inspection_amendments_on_organization_id"
  end

  create_table "inspection_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "condition", null: false
    t.integer "condition_score", null: false
    t.datetime "created_at", null: false
    t.text "damage_description"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.uuid "inspection_id", null: false
    t.uuid "inspection_room_id", null: false
    t.string "item_category"
    t.string "item_name", null: false
    t.string "item_type_name", null: false
    t.text "notes"
    t.uuid "organization_id", null: false
    t.uuid "property_item_id"
    t.string "responsibility"
    t.datetime "updated_at", null: false
    t.index ["inspection_id", "property_item_id"], name: "index_inspection_items_on_inspection_id_and_property_item_id"
    t.index ["inspection_id"], name: "index_inspection_items_on_inspection_id"
    t.index ["inspection_room_id"], name: "index_inspection_items_on_inspection_room_id"
    t.index ["organization_id", "inspection_id"], name: "index_inspection_items_on_organization_id_and_inspection_id"
    t.index ["organization_id"], name: "index_inspection_items_on_organization_id"
    t.index ["property_item_id"], name: "index_inspection_items_on_property_item_id"
    t.check_constraint "condition::text = ANY (ARRAY['good'::character varying::text, 'fair'::character varying::text, 'poor'::character varying::text, 'damaged'::character varying::text, 'missing'::character varying::text])", name: "inspection_items_condition_check"
    t.check_constraint "condition_score >= 1 AND condition_score <= 5", name: "inspection_items_condition_score_range"
    t.check_constraint "responsibility::text = ANY (ARRAY['landlord'::character varying::text, 'tenant'::character varying::text, 'shared'::character varying::text, 'unknown'::character varying::text])", name: "inspection_items_responsibility_check"
  end

  create_table "inspection_photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "caption"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.uuid "inspection_id", null: false
    t.uuid "inspection_item_id"
    t.uuid "inspection_room_id"
    t.uuid "organization_id", null: false
    t.string "storage_key", null: false
    t.datetime "taken_at"
    t.datetime "updated_at", null: false
    t.index ["inspection_id"], name: "index_inspection_photos_on_inspection_id"
    t.index ["inspection_item_id"], name: "index_inspection_photos_on_inspection_item_id"
    t.index ["inspection_room_id"], name: "index_inspection_photos_on_inspection_room_id"
    t.index ["organization_id", "inspection_id"], name: "index_inspection_photos_on_organization_id_and_inspection_id"
    t.index ["organization_id"], name: "index_inspection_photos_on_organization_id"
    t.check_constraint "inspection_room_id IS NOT NULL OR inspection_item_id IS NOT NULL", name: "inspection_photos_must_have_parent"
  end

  create_table "inspection_rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "building_id", null: false
    t.datetime "created_at", null: false
    t.integer "floor_number"
    t.uuid "inspection_id", null: false
    t.text "notes"
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.uuid "room_id", null: false
    t.string "room_name", null: false
    t.string "room_type", null: false
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["inspection_id", "room_id"], name: "index_inspection_rooms_on_inspection_id_and_room_id", unique: true
    t.index ["inspection_id"], name: "index_inspection_rooms_on_inspection_id"
    t.index ["organization_id", "inspection_id"], name: "index_inspection_rooms_on_organization_id_and_inspection_id"
    t.index ["organization_id", "property_id"], name: "index_inspection_rooms_on_organization_id_and_property_id"
    t.index ["organization_id"], name: "index_inspection_rooms_on_organization_id"
    t.index ["room_id"], name: "index_inspection_rooms_on_room_id"
  end

  create_table "inspections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "inspected_on"
    t.string "inspection_type", null: false
    t.uuid "inspector_id", null: false
    t.datetime "locked_at"
    t.text "notes"
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.date "scheduled_on"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["inspector_id"], name: "index_inspections_on_inspector_id"
    t.index ["organization_id", "inspection_type"], name: "index_inspections_on_organization_id_and_inspection_type"
    t.index ["organization_id", "property_id"], name: "index_inspections_on_organization_id_and_property_id"
    t.index ["organization_id", "status"], name: "index_inspections_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_inspections_on_organization_id"
    t.index ["property_id"], name: "index_inspections_on_property_id"
    t.check_constraint "inspection_type::text = ANY (ARRAY['move_in'::character varying::text, 'move_out'::character varying::text, 'routine'::character varying::text, 'periodic'::character varying::text])", name: "inspections_inspection_type_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'in_progress'::character varying::text, 'completed'::character varying::text, 'locked'::character varying::text])", name: "inspections_status_check"
  end

  create_table "item_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "category"], name: "index_item_types_on_organization_id_and_category"
    t.index ["organization_id", "name"], name: "index_item_types_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_item_types_on_organization_id"
  end

  create_table "lease_extension_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "lease_id", null: false
    t.uuid "lease_renewal_proposal_id"
    t.text "message"
    t.uuid "organization_id", null: false
    t.uuid "requested_by_id", null: false
    t.date "requested_end_date"
    t.datetime "responded_at"
    t.uuid "responded_by_id"
    t.text "response_notes"
    t.string "status", default: "pending", null: false
    t.uuid "tenant_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["lease_id"], name: "index_lease_extension_requests_on_lease_id"
    t.index ["lease_renewal_proposal_id"], name: "index_lease_extension_requests_on_lease_renewal_proposal_id"
    t.index ["organization_id", "lease_id", "status"], name: "idx_lease_extension_requests_scope"
    t.index ["organization_id"], name: "index_lease_extension_requests_on_organization_id"
    t.index ["requested_by_id"], name: "index_lease_extension_requests_on_requested_by_id"
    t.index ["responded_by_id"], name: "index_lease_extension_requests_on_responded_by_id"
    t.index ["tenant_profile_id"], name: "index_lease_extension_requests_on_tenant_profile_id"
    t.check_constraint "(responded_at IS NULL) = (responded_by_id IS NULL)", name: "lease_extension_requests_response_metadata_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'proposal_created'::character varying, 'rejected'::character varying, 'withdrawn'::character varying, 'closed'::character varying]::text[])", name: "lease_extension_requests_status_check"
  end

  create_table "lease_renewal_proposals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "created_by_id", null: false
    t.uuid "document_id"
    t.datetime "expires_at"
    t.uuid "lease_id", null: false
    t.uuid "organization_id", null: false
    t.date "proposed_end_date", null: false
    t.decimal "proposed_monthly_rent", precision: 15, scale: 2, null: false
    t.date "proposed_start_date", null: false
    t.text "proposed_terms"
    t.string "rent_currency", default: "ZAR", null: false
    t.datetime "responded_at"
    t.uuid "responded_by_id"
    t.string "response_notes"
    t.uuid "resulting_lease_id"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.integer "version_number", null: false
    t.index ["created_by_id"], name: "index_lease_renewal_proposals_on_created_by_id"
    t.index ["document_id"], name: "index_lease_renewal_proposals_on_document_id"
    t.index ["lease_id", "version_number"], name: "idx_lease_renewal_proposals_version", unique: true
    t.index ["lease_id"], name: "index_lease_renewal_proposals_on_lease_id"
    t.index ["organization_id"], name: "index_lease_renewal_proposals_on_organization_id"
    t.index ["responded_by_id"], name: "index_lease_renewal_proposals_on_responded_by_id"
    t.index ["resulting_lease_id"], name: "index_lease_renewal_proposals_on_resulting_lease_id", unique: true
    t.check_constraint "(responded_at IS NULL) = (responded_by_id IS NULL) OR status::text = 'expired'::text", name: "lease_renewal_proposals_response_metadata_check"
    t.check_constraint "rent_currency::text ~ '^[A-Z]{3}$'::text", name: "lease_renewal_proposals_currency_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'offered'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'expired'::character varying, 'withdrawn'::character varying]::text[])", name: "lease_renewal_proposals_status_check"
    t.check_constraint "version_number > 0 AND proposed_end_date >= proposed_start_date AND proposed_monthly_rent >= 0::numeric", name: "lease_renewal_proposals_terms_check"
  end

  create_table "leases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "deposit_amount", precision: 15, scale: 2
    t.date "end_date"
    t.string "lease_type", default: "fixed_term", null: false
    t.decimal "monthly_rent", precision: 15, scale: 2, null: false
    t.integer "notice_period_days", default: 30
    t.uuid "organization_id", null: false
    t.uuid "previous_lease_id"
    t.uuid "property_id", null: false
    t.string "rent_currency", default: "ZAR"
    t.date "signed_date"
    t.date "start_date", null: false
    t.string "status", default: "draft", null: false
    t.uuid "tenant_id", null: false
    t.text "terms_summary"
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "status"], name: "index_leases_on_organization_id_and_status"
    t.index ["organization_id", "tenant_id"], name: "index_leases_on_organization_id_and_tenant_id"
    t.index ["organization_id", "unit_id"], name: "index_leases_on_organization_id_and_unit_id"
    t.index ["organization_id"], name: "index_leases_on_organization_id"
    t.index ["previous_lease_id"], name: "index_leases_on_previous_lease_id", unique: true
    t.index ["property_id"], name: "index_leases_on_property_id"
    t.index ["tenant_id"], name: "index_leases_on_tenant_id"
    t.index ["unit_id"], name: "index_leases_on_unit_id"
    t.check_constraint "lease_type::text = ANY (ARRAY['fixed_term'::character varying, 'month_to_month'::character varying, 'periodic'::character varying]::text[])", name: "leases_lease_type_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'expired'::character varying, 'terminated'::character varying, 'cancelled'::character varying]::text[])", name: "leases_status_check"
  end

  create_table "maintenance_cost_allocations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "allocated_amount", precision: 12, scale: 2, null: false
    t.decimal "allocation_percentage", precision: 5, scale: 2
    t.datetime "approved_at"
    t.uuid "approved_by_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.uuid "lease_id"
    t.uuid "maintenance_request_id", null: false
    t.uuid "organization_id", null: false
    t.uuid "party_id"
    t.uuid "property_ownership_id"
    t.text "rationale", null: false
    t.string "responsible_party", null: false
    t.string "status", default: "approved", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_maintenance_cost_allocations_on_approved_by_id"
    t.index ["lease_id"], name: "index_maintenance_cost_allocations_on_lease_id"
    t.index ["maintenance_request_id"], name: "index_maintenance_cost_allocations_on_maintenance_request_id"
    t.index ["organization_id", "maintenance_request_id"], name: "idx_maint_alloc_org_request"
    t.index ["organization_id"], name: "index_maintenance_cost_allocations_on_organization_id"
    t.index ["party_id"], name: "index_maintenance_cost_allocations_on_party_id"
    t.index ["property_ownership_id"], name: "index_maintenance_cost_allocations_on_property_ownership_id"
    t.check_constraint "allocated_amount >= 0::numeric", name: "maintenance_cost_allocations_amount_check"
    t.check_constraint "allocation_percentage IS NULL OR allocation_percentage >= 0::numeric AND allocation_percentage <= 100::numeric", name: "maintenance_cost_allocations_percentage_check"
    t.check_constraint "responsible_party::text = ANY (ARRAY['owner'::character varying, 'tenant'::character varying, 'shared'::character varying, 'other'::character varying, 'organization'::character varying, 'third_party'::character varying]::text[])", name: "maintenance_cost_allocations_party_check"
    t.check_constraint "status::text = ANY (ARRAY['approved'::character varying, 'superseded'::character varying]::text[])", name: "maintenance_cost_allocations_status_check"
  end

  create_table "maintenance_financial_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.datetime "decision_at"
    t.uuid "decision_by_id"
    t.text "decision_reason"
    t.date "due_on"
    t.string "entry_type", null: false
    t.uuid "invoice_id"
    t.string "invoice_reference"
    t.uuid "maintenance_request_id", null: false
    t.text "notes"
    t.date "occurred_on", null: false
    t.uuid "organization_id", null: false
    t.uuid "party_id"
    t.uuid "recorded_by_id", null: false
    t.string "reference"
    t.string "status", default: "recorded", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.date "valid_until"
    t.index ["decision_by_id"], name: "index_maintenance_financial_entries_on_decision_by_id"
    t.index ["invoice_id"], name: "index_maintenance_financial_entries_on_invoice_id"
    t.index ["maintenance_request_id"], name: "idx_maintenance_entries_one_selected_quote", unique: true, where: "(((type)::text = 'MaintenanceQuote'::text) AND ((status)::text = 'selected'::text))"
    t.index ["maintenance_request_id"], name: "index_maintenance_financial_entries_on_maintenance_request_id"
    t.index ["organization_id", "maintenance_request_id", "entry_type"], name: "idx_maint_finance_org_req_type"
    t.index ["organization_id", "party_id", "invoice_reference"], name: "idx_maintenance_invoice_reference", unique: true, where: "(((type)::text = 'MaintenanceInvoice'::text) AND (invoice_reference IS NOT NULL) AND ((invoice_reference)::text <> ''::text))"
    t.index ["organization_id"], name: "index_maintenance_financial_entries_on_organization_id"
    t.index ["party_id"], name: "index_maintenance_financial_entries_on_party_id"
    t.index ["recorded_by_id"], name: "index_maintenance_financial_entries_on_recorded_by_id"
    t.check_constraint "amount >= 0::numeric", name: "maintenance_financial_entries_amount_check"
    t.check_constraint "entry_type::text = ANY (ARRAY['quotation'::character varying, 'invoice'::character varying, 'payment'::character varying]::text[])", name: "maintenance_financial_entries_type_check"
    t.check_constraint "status::text = ANY (ARRAY['recorded'::character varying, 'draft'::character varying, 'received'::character varying, 'selected'::character varying, 'rejected'::character varying, 'expired'::character varying, 'superseded'::character varying, 'approved'::character varying, 'partially_paid'::character varying, 'paid'::character varying, 'overdue'::character varying, 'disputed'::character varying, 'cancelled'::character varying, 'pending'::character varying, 'failed'::character varying]::text[])", name: "maintenance_financial_entries_status_check"
    t.check_constraint "type IS NULL AND invoice_id IS NULL OR type::text = 'MaintenancePayment'::text AND invoice_id IS NOT NULL OR (type::text = ANY (ARRAY['MaintenanceQuote'::character varying, 'MaintenanceInvoice'::character varying]::text[])) AND invoice_id IS NULL", name: "maintenance_financial_entries_payment_invoice_check"
    t.check_constraint "type IS NULL OR (type::text = ANY (ARRAY['MaintenanceQuote'::character varying, 'MaintenanceInvoice'::character varying, 'MaintenancePayment'::character varying]::text[]))", name: "maintenance_financial_entries_sti_type_check"
    t.check_constraint "type IS NULL OR type::text = 'MaintenanceQuote'::text AND entry_type::text = 'quotation'::text OR type::text = 'MaintenanceInvoice'::text AND entry_type::text = 'invoice'::text OR type::text = 'MaintenancePayment'::text AND entry_type::text = 'payment'::text", name: "maintenance_financial_entries_sti_entry_type_check"
  end

  create_table "maintenance_request_updates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "author_id", null: false
    t.text "body", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.uuid "maintenance_request_id", null: false
    t.uuid "organization_id", null: false
    t.datetime "published_at"
    t.uuid "published_by_id"
    t.datetime "scheduled_end_at"
    t.datetime "scheduled_start_at"
    t.string "status", default: "draft", null: false
    t.string "update_type", default: "update", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_maintenance_request_updates_on_author_id"
    t.index ["maintenance_request_id"], name: "index_maintenance_request_updates_on_maintenance_request_id"
    t.index ["organization_id", "maintenance_request_id", "status"], name: "idx_maintenance_updates_request_status"
    t.index ["organization_id"], name: "index_maintenance_request_updates_on_organization_id"
    t.index ["published_by_id"], name: "index_maintenance_request_updates_on_published_by_id"
    t.check_constraint "(scheduled_start_at IS NULL OR scheduled_end_at IS NULL OR scheduled_end_at >= scheduled_start_at) AND (status::text <> 'published'::text OR published_at IS NOT NULL AND published_by_id IS NOT NULL)", name: "maintenance_request_updates_timing_publication_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'published'::character varying, 'withdrawn'::character varying]::text[])", name: "maintenance_request_updates_status_check"
    t.check_constraint "update_type::text = ANY (ARRAY['status'::character varying, 'update'::character varying, 'scheduled_visit'::character varying, 'completion'::character varying]::text[])", name: "maintenance_request_updates_type_check"
  end

  create_table "maintenance_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "acknowledged_at"
    t.decimal "actual_cost", precision: 12, scale: 2
    t.datetime "actual_started_at"
    t.text "approval_notes"
    t.datetime "approved_at"
    t.uuid "approved_by_id"
    t.decimal "approved_cost", precision: 12, scale: 2
    t.uuid "assigned_to_id"
    t.text "cancellation_reason"
    t.string "category"
    t.string "classification", default: "undetermined", null: false
    t.datetime "closed_at"
    t.uuid "closed_by_id"
    t.uuid "contractor_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "ZAR", null: false
    t.text "description"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.uuid "lease_id"
    t.uuid "maintenance_schedule_id"
    t.date "occurrence_on"
    t.uuid "organization_id", null: false
    t.date "overdue_notified_for"
    t.string "priority", default: "medium", null: false
    t.uuid "property_id", null: false
    t.datetime "rejected_at"
    t.uuid "rejected_by_id"
    t.text "rejection_reason"
    t.datetime "reported_at", null: false
    t.uuid "reported_by_id", null: false
    t.text "resolution_notes"
    t.datetime "resolved_at"
    t.text "responsibility_notes"
    t.datetime "responsibility_reviewed_at"
    t.uuid "responsibility_reviewed_by_id"
    t.string "responsibility_status", default: "pending_review", null: false
    t.uuid "room_id"
    t.date "scheduled_on"
    t.uuid "source_damage_assessment_id"
    t.uuid "source_inspection_id"
    t.uuid "source_inspection_item_id"
    t.string "source_type", default: "manager", null: false
    t.string "status", default: "open", null: false
    t.string "suggested_responsibility", default: "unknown", null: false
    t.date "target_completion_on"
    t.string "title", null: false
    t.uuid "unit_id"
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.uuid "verified_by_id"
    t.index ["approved_by_id"], name: "index_maintenance_requests_on_approved_by_id"
    t.index ["assigned_to_id"], name: "index_maintenance_requests_on_assigned_to_id"
    t.index ["closed_by_id"], name: "index_maintenance_requests_on_closed_by_id"
    t.index ["contractor_id"], name: "index_maintenance_requests_on_contractor_id"
    t.index ["lease_id"], name: "index_maintenance_requests_on_lease_id"
    t.index ["maintenance_schedule_id", "occurrence_on"], name: "idx_maintenance_requests_schedule_occurrence", unique: true, where: "((maintenance_schedule_id IS NOT NULL) AND (occurrence_on IS NOT NULL))"
    t.index ["organization_id", "priority"], name: "index_maintenance_requests_on_organization_id_and_priority"
    t.index ["organization_id", "property_id"], name: "index_maintenance_requests_on_organization_id_and_property_id"
    t.index ["organization_id", "status"], name: "index_maintenance_requests_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_maintenance_requests_on_organization_id"
    t.index ["property_id"], name: "index_maintenance_requests_on_property_id"
    t.index ["rejected_by_id"], name: "index_maintenance_requests_on_rejected_by_id"
    t.index ["reported_by_id"], name: "index_maintenance_requests_on_reported_by_id"
    t.index ["responsibility_reviewed_by_id"], name: "index_maintenance_requests_on_responsibility_reviewed_by_id"
    t.index ["room_id"], name: "index_maintenance_requests_on_room_id"
    t.index ["source_damage_assessment_id"], name: "idx_maint_req_source_damage_assessment", unique: true, where: "(source_damage_assessment_id IS NOT NULL)"
    t.index ["source_inspection_id"], name: "index_maintenance_requests_on_source_inspection_id"
    t.index ["source_inspection_item_id"], name: "idx_maint_req_source_inspection_item", unique: true, where: "(source_inspection_item_id IS NOT NULL)"
    t.index ["target_completion_on"], name: "idx_maint_requests_target_completion", where: "(target_completion_on IS NOT NULL)"
    t.index ["unit_id"], name: "index_maintenance_requests_on_unit_id"
    t.index ["verified_by_id"], name: "index_maintenance_requests_on_verified_by_id"
    t.check_constraint "(estimated_cost IS NULL OR estimated_cost >= 0::numeric) AND (approved_cost IS NULL OR approved_cost >= 0::numeric) AND (actual_cost IS NULL OR actual_cost >= 0::numeric)", name: "maintenance_requests_costs_check"
    t.check_constraint "classification::text = ANY (ARRAY['wear_and_tear'::character varying, 'accidental_damage'::character varying, 'negligence'::character varying, 'misuse'::character varying, 'structural_deterioration'::character varying, 'preventative_maintenance'::character varying, 'breakdown'::character varying, 'improvement'::character varying, 'compliance_safety'::character varying, 'other'::character varying, 'undetermined'::character varying]::text[])", name: "maintenance_requests_classification_check"
    t.check_constraint "priority::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'urgent'::character varying]::text[])", name: "maintenance_requests_priority_check"
    t.check_constraint "responsibility_status::text = ANY (ARRAY['pending_review'::character varying, 'approved'::character varying, 'disputed'::character varying]::text[])", name: "maintenance_requests_responsibility_status_check"
    t.check_constraint "source_type::text = ANY (ARRAY['tenant_request'::character varying, 'schedule'::character varying, 'inspection'::character varying, 'damage_assessment'::character varying, 'manager'::character varying, 'other'::character varying]::text[])", name: "maintenance_requests_source_type_check"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'acknowledged'::character varying, 'awaiting_approval'::character varying, 'approved'::character varying, 'scheduled'::character varying, 'in_progress'::character varying, 'resolved'::character varying, 'closed'::character varying, 'rejected'::character varying, 'disputed'::character varying, 'cancelled'::character varying]::text[])", name: "maintenance_requests_status_check"
    t.check_constraint "suggested_responsibility::text = ANY (ARRAY['owner'::character varying, 'tenant'::character varying, 'shared'::character varying, 'organization'::character varying, 'third_party'::character varying, 'unknown'::character varying]::text[])", name: "maintenance_requests_suggested_responsibility_check"
  end

  create_table "maintenance_schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assigned_to_id"
    t.string "category"
    t.string "classification", default: "undetermined", null: false
    t.uuid "contractor_id"
    t.datetime "created_at", null: false
    t.uuid "created_by_id", null: false
    t.string "currency", default: "ZAR", null: false
    t.text "description"
    t.date "ends_on"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.string "frequency", default: "once", null: false
    t.string "generation_mode", default: "proposed", null: false
    t.integer "interval_months"
    t.string "interval_unit"
    t.integer "interval_value"
    t.date "last_overdue_notified_for"
    t.date "last_reminder_sent_for"
    t.date "next_due_on", null: false
    t.uuid "organization_id", null: false
    t.string "priority", default: "medium", null: false
    t.uuid "property_id", null: false
    t.integer "reminder_days", default: 7, null: false
    t.uuid "room_id"
    t.date "starts_on", null: false
    t.string "status", default: "active", null: false
    t.string "suggested_responsibility", default: "pending", null: false
    t.date "target_completion_on"
    t.string "title", null: false
    t.uuid "unit_id"
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_maintenance_schedules_on_assigned_to_id"
    t.index ["contractor_id"], name: "index_maintenance_schedules_on_contractor_id"
    t.index ["created_by_id"], name: "index_maintenance_schedules_on_created_by_id"
    t.index ["next_due_on"], name: "idx_maint_schedules_active_due", where: "((status)::text = 'active'::text)"
    t.index ["organization_id", "property_id", "status"], name: "idx_maint_sched_org_property_status"
    t.index ["organization_id"], name: "index_maintenance_schedules_on_organization_id"
    t.index ["property_id"], name: "index_maintenance_schedules_on_property_id"
    t.index ["room_id"], name: "index_maintenance_schedules_on_room_id"
    t.index ["unit_id"], name: "index_maintenance_schedules_on_unit_id"
    t.check_constraint "classification::text = ANY (ARRAY['wear_and_tear'::character varying, 'accidental_damage'::character varying, 'negligence'::character varying, 'misuse'::character varying, 'structural_deterioration'::character varying, 'preventative_maintenance'::character varying, 'breakdown'::character varying, 'improvement'::character varying, 'compliance_safety'::character varying, 'other'::character varying, 'undetermined'::character varying]::text[])", name: "maintenance_schedules_classification_check"
    t.check_constraint "estimated_cost IS NULL OR estimated_cost >= 0::numeric", name: "maintenance_schedules_estimated_cost_check"
    t.check_constraint "frequency::text <> 'custom'::text OR interval_months IS NOT NULL OR interval_value IS NOT NULL AND interval_unit IS NOT NULL", name: "maintenance_schedules_custom_interval_check"
    t.check_constraint "frequency::text = ANY (ARRAY['once'::character varying, 'daily'::character varying, 'weekly'::character varying, 'monthly'::character varying, 'quarterly'::character varying, 'semi_annual'::character varying, 'annual'::character varying, 'custom'::character varying]::text[])", name: "maintenance_schedules_frequency_check"
    t.check_constraint "generation_mode::text = ANY (ARRAY['automatic'::character varying, 'proposed'::character varying, 'reminder_only'::character varying]::text[])", name: "maintenance_schedules_generation_mode_check"
    t.check_constraint "interval_months IS NULL OR interval_months > 0", name: "maintenance_schedules_interval_months_check"
    t.check_constraint "interval_unit IS NULL OR (interval_unit::text = ANY (ARRAY['day'::character varying, 'week'::character varying, 'month'::character varying]::text[]))", name: "maintenance_schedules_interval_unit_check"
    t.check_constraint "interval_value IS NULL OR interval_value > 0", name: "maintenance_schedules_interval_value_check"
    t.check_constraint "priority::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'urgent'::character varying]::text[])", name: "maintenance_schedules_priority_check"
    t.check_constraint "reminder_days >= 0", name: "maintenance_schedules_reminder_days_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'paused'::character varying, 'completed'::character varying]::text[])", name: "maintenance_schedules_status_check"
    t.check_constraint "suggested_responsibility::text = ANY (ARRAY['owner'::character varying, 'tenant'::character varying, 'shared'::character varying, 'other'::character varying, 'pending'::character varying, 'organization'::character varying, 'third_party'::character varying, 'unknown'::character varying]::text[])", name: "maintenance_schedules_responsibility_check"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "parties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.string "party_type", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "party_type"], name: "index_parties_on_organization_id_and_party_type"
    t.index ["organization_id"], name: "index_parties_on_organization_id"
  end

  create_table "party_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.uuid "party_id", null: false
    t.datetime "revoked_at"
    t.uuid "revoked_by_id"
    t.string "status", default: "pending_verification", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.datetime "verified_at"
    t.uuid "verified_by_id"
    t.index ["organization_id", "user_id", "party_id"], name: "idx_party_accounts_org_user_party", unique: true
    t.index ["organization_id"], name: "index_party_accounts_on_organization_id"
    t.index ["party_id"], name: "index_party_accounts_on_party_id"
    t.index ["revoked_by_id"], name: "index_party_accounts_on_revoked_by_id"
    t.index ["user_id"], name: "index_party_accounts_on_user_id"
    t.index ["verified_by_id"], name: "index_party_accounts_on_verified_by_id"
    t.check_constraint "(revoked_at IS NULL) = (revoked_by_id IS NULL)", name: "party_accounts_revocation_metadata_check"
    t.check_constraint "(status::text <> 'verified'::text OR verified_at IS NOT NULL) AND (status::text <> 'revoked'::text OR revoked_at IS NOT NULL)", name: "party_accounts_status_metadata_check"
    t.check_constraint "(verified_at IS NULL) = (verified_by_id IS NULL)", name: "party_accounts_verification_metadata_check"
    t.check_constraint "status::text = ANY (ARRAY['pending_verification'::character varying, 'verified'::character varying, 'revoked'::character varying]::text[])", name: "party_accounts_status_check"
  end

  create_table "platform_administrator_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "granted_by_id", null: false
    t.string "reason", null: false
    t.datetime "revoked_at"
    t.uuid "revoked_by_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["granted_by_id"], name: "index_platform_administrator_grants_on_granted_by_id"
    t.index ["revoked_by_id"], name: "index_platform_administrator_grants_on_revoked_by_id"
    t.index ["user_id"], name: "idx_platform_admin_grants_active_user", unique: true, where: "(revoked_at IS NULL)"
    t.index ["user_id"], name: "index_platform_administrator_grants_on_user_id"
    t.check_constraint "(revoked_at IS NULL) = (revoked_by_id IS NULL)", name: "platform_admin_grants_revocation_metadata_check"
  end

  create_table "properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address_line_1"
    t.string "address_line_2"
    t.decimal "building_size", precision: 12, scale: 2
    t.integer "cached_total_bedrooms", default: 0, null: false
    t.integer "cached_total_units", default: 0, null: false
    t.string "city"
    t.string "condition"
    t.string "country"
    t.string "cover_photo_url"
    t.datetime "created_at", null: false
    t.decimal "current_value", precision: 15, scale: 2
    t.text "description"
    t.decimal "land_size", precision: 12, scale: 2
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.decimal "original_value", precision: 15, scale: 2
    t.string "postal_code"
    t.string "property_subtype"
    t.string "property_type", null: false
    t.string "province"
    t.string "suburb"
    t.datetime "updated_at", null: false
    t.integer "year_established"
    t.index ["organization_id", "name"], name: "index_properties_on_organization_id_and_name"
    t.index ["organization_id"], name: "index_properties_on_organization_id"
  end

  create_table "property_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "assignment_type", null: false
    t.string "capabilities", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["organization_id", "property_id", "user_id"], name: "idx_property_assignments_scope", unique: true
    t.index ["organization_id", "property_id"], name: "index_property_assignments_on_organization_id_and_property_id"
    t.index ["organization_id"], name: "index_property_assignments_on_organization_id"
    t.index ["property_id"], name: "index_property_assignments_on_property_id"
    t.index ["user_id"], name: "index_property_assignments_on_user_id"
    t.check_constraint "capabilities <@ ARRAY['invite_tenants'::character varying, 'propose_lease_renewals'::character varying, 'publish_tenant_information'::character varying]", name: "property_assignments_capabilities_check"
  end

  create_table "property_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "building_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.date "installed_at"
    t.uuid "item_type_id", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.uuid "room_id", null: false
    t.string "serial_number"
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["building_id"], name: "index_property_items_on_building_id"
    t.index ["item_type_id"], name: "index_property_items_on_item_type_id"
    t.index ["organization_id", "building_id"], name: "index_property_items_on_organization_id_and_building_id"
    t.index ["organization_id", "property_id"], name: "index_property_items_on_organization_id_and_property_id"
    t.index ["organization_id", "room_id"], name: "index_property_items_on_organization_id_and_room_id"
    t.index ["organization_id", "unit_id"], name: "index_property_items_on_organization_id_and_unit_id"
    t.index ["organization_id"], name: "index_property_items_on_organization_id"
    t.index ["property_id"], name: "index_property_items_on_property_id"
    t.index ["room_id"], name: "index_property_items_on_room_id"
    t.index ["unit_id"], name: "index_property_items_on_unit_id"
  end

  create_table "property_ownerships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "conveyancer"
    t.datetime "created_at", null: false
    t.string "currency"
    t.date "end_date"
    t.text "notes"
    t.uuid "organization_id", null: false
    t.decimal "ownership_percentage", precision: 5, scale: 2, null: false
    t.uuid "party_id", null: false
    t.uuid "property_id", null: false
    t.date "start_date", null: false
    t.string "transfer_reference"
    t.string "transfer_type"
    t.decimal "transfer_value", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "valuation_at_transfer", precision: 15, scale: 2
    t.string "verification_status", default: "unverified", null: false
    t.datetime "verified_at"
    t.uuid "verified_by_id"
    t.index ["organization_id", "party_id"], name: "index_property_ownerships_on_organization_id_and_party_id"
    t.index ["organization_id", "property_id"], name: "index_property_ownerships_on_organization_id_and_property_id"
    t.index ["organization_id", "transfer_reference"], name: "index_property_ownerships_on_org_and_transfer_reference"
    t.index ["organization_id"], name: "index_property_ownerships_on_organization_id"
    t.index ["party_id"], name: "index_property_ownerships_on_party_id"
    t.index ["property_id", "start_date"], name: "index_property_ownerships_on_property_and_start_date"
    t.index ["property_id"], name: "index_property_ownerships_on_property_id"
    t.index ["verified_by_id"], name: "index_property_ownerships_on_verified_by_id"
    t.check_constraint "ownership_percentage > 0::numeric AND ownership_percentage <= 100::numeric", name: "property_ownerships_ownership_percentage_range"
    t.check_constraint "verification_status::text = ANY (ARRAY['unverified'::character varying, 'pending_review'::character varying, 'verified'::character varying]::text[])", name: "property_ownerships_verification_status_check"
  end

  create_table "property_photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "caption"
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.uuid "property_id", null: false
    t.datetime "published_at"
    t.uuid "published_by_id"
    t.datetime "updated_at", null: false
    t.uuid "uploaded_by_id", null: false
    t.string "visibility", default: "internal", null: false
    t.index ["organization_id", "property_id", "visibility", "position"], name: "idx_property_photos_tenant_visibility"
    t.index ["organization_id"], name: "index_property_photos_on_organization_id"
    t.index ["property_id"], name: "index_property_photos_on_property_id"
    t.index ["published_by_id"], name: "index_property_photos_on_published_by_id"
    t.index ["uploaded_by_id"], name: "index_property_photos_on_uploaded_by_id"
    t.check_constraint "(visibility::text = ANY (ARRAY['internal'::character varying, 'tenant_visible'::character varying]::text[])) AND \"position\" >= 0", name: "property_photos_visibility_position_check"
    t.check_constraint "visibility::text <> 'tenant_visible'::text OR published_at IS NOT NULL AND published_by_id IS NOT NULL", name: "property_photos_publication_metadata_check"
  end

  create_table "rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "building_id", null: false
    t.string "condition"
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "floor_area", precision: 10, scale: 2
    t.integer "floor_number"
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.string "room_name", null: false
    t.string "room_type", null: false
    t.string "status", default: "active", null: false
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["building_id"], name: "index_rooms_on_building_id"
    t.index ["organization_id", "building_id"], name: "index_rooms_on_organization_id_and_building_id"
    t.index ["organization_id", "property_id"], name: "index_rooms_on_organization_id_and_property_id"
    t.index ["organization_id", "unit_id"], name: "index_rooms_on_organization_id_and_unit_id"
    t.index ["organization_id"], name: "index_rooms_on_organization_id"
    t.index ["property_id"], name: "index_rooms_on_property_id"
    t.index ["status"], name: "index_rooms_on_status"
    t.index ["unit_id", "room_name"], name: "index_rooms_on_unit_id_and_room_name", unique: true
    t.index ["unit_id", "status"], name: "index_rooms_on_unit_id_and_status"
    t.index ["unit_id"], name: "index_rooms_on_unit_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'under_maintenance'::character varying::text])", name: "rooms_status_check"
  end

  create_table "tenant_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.uuid "accepted_user_id"
    t.datetime "created_at", null: false
    t.datetime "expired_at"
    t.datetime "expires_at", null: false
    t.uuid "invited_by_id", null: false
    t.uuid "lease_id", null: false
    t.uuid "organization_id", null: false
    t.uuid "property_id", null: false
    t.datetime "revoked_at"
    t.uuid "revoked_by_id"
    t.string "status", default: "pending", null: false
    t.string "target_email", null: false
    t.uuid "tenant_party_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_user_id"], name: "index_tenant_invitations_on_accepted_user_id"
    t.index ["invited_by_id"], name: "index_tenant_invitations_on_invited_by_id"
    t.index ["lease_id"], name: "index_tenant_invitations_on_lease_id"
    t.index ["organization_id", "lease_id", "target_email"], name: "idx_tenant_invitations_pending_email", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["organization_id"], name: "index_tenant_invitations_on_organization_id"
    t.index ["property_id"], name: "index_tenant_invitations_on_property_id"
    t.index ["revoked_by_id"], name: "index_tenant_invitations_on_revoked_by_id"
    t.index ["tenant_party_id"], name: "index_tenant_invitations_on_tenant_party_id"
    t.index ["token_digest"], name: "index_tenant_invitations_on_token_digest", unique: true
    t.check_constraint "(accepted_at IS NULL) = (accepted_user_id IS NULL)", name: "tenant_invitations_acceptance_metadata_check"
    t.check_constraint "(revoked_at IS NULL) = (revoked_by_id IS NULL)", name: "tenant_invitations_revocation_metadata_check"
    t.check_constraint "(status::text <> 'accepted'::text OR accepted_at IS NOT NULL) AND (status::text <> 'revoked'::text OR revoked_at IS NOT NULL) AND (status::text <> 'expired'::text OR expired_at IS NOT NULL)", name: "tenant_invitations_status_metadata_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'revoked'::character varying, 'expired'::character varying]::text[])", name: "tenant_invitations_status_check"
  end

  create_table "tenant_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.uuid "lease_extension_request_id"
    t.uuid "lease_id"
    t.uuid "lease_renewal_proposal_id"
    t.uuid "maintenance_request_update_id"
    t.string "notification_type", null: false
    t.uuid "organization_id", null: false
    t.datetime "read_at"
    t.uuid "tenant_profile_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["lease_extension_request_id"], name: "index_tenant_notifications_on_lease_extension_request_id"
    t.index ["lease_id"], name: "index_tenant_notifications_on_lease_id"
    t.index ["lease_renewal_proposal_id"], name: "index_tenant_notifications_on_lease_renewal_proposal_id"
    t.index ["maintenance_request_update_id"], name: "index_tenant_notifications_on_maintenance_request_update_id"
    t.index ["organization_id", "tenant_profile_id", "created_at"], name: "idx_tenant_notifications_profile"
    t.index ["organization_id"], name: "index_tenant_notifications_on_organization_id"
    t.index ["tenant_profile_id"], name: "index_tenant_notifications_on_tenant_profile_id"
    t.check_constraint "notification_type::text = ANY (ARRAY['lease_expiring'::character varying, 'lease_renewal_proposal'::character varying, 'lease_extension_request'::character varying, 'maintenance_request_update'::character varying]::text[])", name: "tenant_notifications_type_check"
    t.check_constraint "num_nonnulls(lease_id, lease_renewal_proposal_id, lease_extension_request_id, maintenance_request_update_id) = 1", name: "tenant_notifications_single_source_check"
  end

  create_table "tenant_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.uuid "party_account_id", null: false
    t.string "phone_number"
    t.string "tenant_reference"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "tenant_reference"], name: "idx_tenant_profiles_org_reference", unique: true, where: "(tenant_reference IS NOT NULL)"
    t.index ["organization_id"], name: "index_tenant_profiles_on_organization_id"
    t.index ["party_account_id"], name: "index_tenant_profiles_on_party_account_id", unique: true
  end

  create_table "units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "bathrooms", default: 0, null: false
    t.integer "bedrooms", default: 0, null: false
    t.uuid "building_id", null: false
    t.string "condition"
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "floor_area", precision: 12, scale: 2
    t.integer "floor_number"
    t.string "name"
    t.uuid "organization_id", null: false
    t.integer "parking_spaces", default: 0, null: false
    t.uuid "property_id", null: false
    t.string "status", default: "active", null: false
    t.string "unit_number"
    t.string "unit_subtype"
    t.string "unit_type"
    t.datetime "updated_at", null: false
    t.index ["building_id"], name: "index_units_on_building_id"
    t.index ["organization_id", "building_id"], name: "index_units_on_organization_id_and_building_id"
    t.index ["organization_id", "property_id"], name: "index_units_on_organization_id_and_property_id"
    t.index ["organization_id"], name: "index_units_on_organization_id"
    t.index ["property_id", "status"], name: "index_units_on_property_id_and_status"
    t.index ["property_id", "unit_number"], name: "index_units_on_property_id_and_unit_number", unique: true
    t.index ["property_id"], name: "index_units_on_property_id"
    t.index ["status"], name: "index_units_on_status"
    t.check_constraint "parking_spaces >= 0", name: "units_parking_spaces_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text, 'under_maintenance'::character varying::text])", name: "units_status_check"
    t.check_constraint "unit_type::text = ANY (ARRAY['residential'::character varying::text, 'commercial'::character varying::text, 'office'::character varying::text, 'retail'::character varying::text, 'industrial'::character varying::text, 'mixed_use'::character varying::text, 'other'::character varying::text])", name: "units_unit_type_check"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "email_verified_at"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.uuid "organization_id", null: false
    t.string "organization_role", default: "member", null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.check_constraint "organization_role::text = ANY (ARRAY['member'::character varying, 'administrator'::character varying]::text[])", name: "users_organization_role_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "buildings", "organizations"
  add_foreign_key "buildings", "properties"
  add_foreign_key "damage_assessments", "inspection_items"
  add_foreign_key "damage_assessments", "inspections"
  add_foreign_key "damage_assessments", "organizations"
  add_foreign_key "damage_assessments", "properties"
  add_foreign_key "damage_assessments", "users", column: "assessed_by_id"
  add_foreign_key "documents", "maintenance_financial_entries"
  add_foreign_key "documents", "maintenance_requests"
  add_foreign_key "documents", "organizations"
  add_foreign_key "documents", "property_ownerships"
  add_foreign_key "documents", "users", column: "published_by_id"
  add_foreign_key "documents", "users", column: "uploaded_by_id"
  add_foreign_key "inspection_amendments", "inspection_items"
  add_foreign_key "inspection_amendments", "inspections"
  add_foreign_key "inspection_amendments", "organizations"
  add_foreign_key "inspection_amendments", "users", column: "amended_by_id"
  add_foreign_key "inspection_items", "inspection_rooms"
  add_foreign_key "inspection_items", "inspections"
  add_foreign_key "inspection_items", "organizations"
  add_foreign_key "inspection_items", "property_items", on_delete: :nullify
  add_foreign_key "inspection_photos", "inspection_items"
  add_foreign_key "inspection_photos", "inspection_rooms"
  add_foreign_key "inspection_photos", "inspections"
  add_foreign_key "inspection_photos", "organizations"
  add_foreign_key "inspection_rooms", "inspections"
  add_foreign_key "inspection_rooms", "organizations"
  add_foreign_key "inspection_rooms", "rooms"
  add_foreign_key "inspections", "organizations"
  add_foreign_key "inspections", "properties"
  add_foreign_key "inspections", "users", column: "inspector_id"
  add_foreign_key "item_types", "organizations"
  add_foreign_key "lease_extension_requests", "lease_renewal_proposals"
  add_foreign_key "lease_extension_requests", "leases"
  add_foreign_key "lease_extension_requests", "organizations"
  add_foreign_key "lease_extension_requests", "tenant_profiles"
  add_foreign_key "lease_extension_requests", "users", column: "requested_by_id"
  add_foreign_key "lease_extension_requests", "users", column: "responded_by_id"
  add_foreign_key "lease_renewal_proposals", "documents"
  add_foreign_key "lease_renewal_proposals", "leases"
  add_foreign_key "lease_renewal_proposals", "leases", column: "resulting_lease_id"
  add_foreign_key "lease_renewal_proposals", "organizations"
  add_foreign_key "lease_renewal_proposals", "users", column: "created_by_id"
  add_foreign_key "lease_renewal_proposals", "users", column: "responded_by_id"
  add_foreign_key "leases", "leases", column: "previous_lease_id"
  add_foreign_key "leases", "organizations"
  add_foreign_key "leases", "parties", column: "tenant_id"
  add_foreign_key "leases", "properties"
  add_foreign_key "leases", "units"
  add_foreign_key "maintenance_cost_allocations", "leases"
  add_foreign_key "maintenance_cost_allocations", "maintenance_requests"
  add_foreign_key "maintenance_cost_allocations", "organizations"
  add_foreign_key "maintenance_cost_allocations", "parties"
  add_foreign_key "maintenance_cost_allocations", "property_ownerships"
  add_foreign_key "maintenance_cost_allocations", "users", column: "approved_by_id"
  add_foreign_key "maintenance_financial_entries", "maintenance_financial_entries", column: "invoice_id"
  add_foreign_key "maintenance_financial_entries", "maintenance_requests"
  add_foreign_key "maintenance_financial_entries", "organizations"
  add_foreign_key "maintenance_financial_entries", "parties"
  add_foreign_key "maintenance_financial_entries", "users", column: "decision_by_id"
  add_foreign_key "maintenance_financial_entries", "users", column: "recorded_by_id"
  add_foreign_key "maintenance_request_updates", "maintenance_requests"
  add_foreign_key "maintenance_request_updates", "organizations"
  add_foreign_key "maintenance_request_updates", "users", column: "author_id"
  add_foreign_key "maintenance_request_updates", "users", column: "published_by_id"
  add_foreign_key "maintenance_requests", "damage_assessments", column: "source_damage_assessment_id"
  add_foreign_key "maintenance_requests", "inspection_items", column: "source_inspection_item_id"
  add_foreign_key "maintenance_requests", "inspections", column: "source_inspection_id"
  add_foreign_key "maintenance_requests", "leases"
  add_foreign_key "maintenance_requests", "maintenance_schedules"
  add_foreign_key "maintenance_requests", "organizations"
  add_foreign_key "maintenance_requests", "parties", column: "contractor_id"
  add_foreign_key "maintenance_requests", "properties"
  add_foreign_key "maintenance_requests", "rooms"
  add_foreign_key "maintenance_requests", "units"
  add_foreign_key "maintenance_requests", "users", column: "approved_by_id"
  add_foreign_key "maintenance_requests", "users", column: "assigned_to_id"
  add_foreign_key "maintenance_requests", "users", column: "closed_by_id"
  add_foreign_key "maintenance_requests", "users", column: "rejected_by_id"
  add_foreign_key "maintenance_requests", "users", column: "reported_by_id"
  add_foreign_key "maintenance_requests", "users", column: "responsibility_reviewed_by_id"
  add_foreign_key "maintenance_requests", "users", column: "verified_by_id"
  add_foreign_key "maintenance_schedules", "organizations"
  add_foreign_key "maintenance_schedules", "parties", column: "contractor_id"
  add_foreign_key "maintenance_schedules", "properties"
  add_foreign_key "maintenance_schedules", "rooms"
  add_foreign_key "maintenance_schedules", "units"
  add_foreign_key "maintenance_schedules", "users", column: "assigned_to_id"
  add_foreign_key "maintenance_schedules", "users", column: "created_by_id"
  add_foreign_key "parties", "organizations"
  add_foreign_key "party_accounts", "organizations"
  add_foreign_key "party_accounts", "parties"
  add_foreign_key "party_accounts", "users"
  add_foreign_key "party_accounts", "users", column: "revoked_by_id"
  add_foreign_key "party_accounts", "users", column: "verified_by_id"
  add_foreign_key "platform_administrator_grants", "users"
  add_foreign_key "platform_administrator_grants", "users", column: "granted_by_id"
  add_foreign_key "platform_administrator_grants", "users", column: "revoked_by_id"
  add_foreign_key "properties", "organizations"
  add_foreign_key "property_assignments", "organizations"
  add_foreign_key "property_assignments", "properties"
  add_foreign_key "property_assignments", "users"
  add_foreign_key "property_items", "buildings"
  add_foreign_key "property_items", "item_types"
  add_foreign_key "property_items", "organizations"
  add_foreign_key "property_items", "properties"
  add_foreign_key "property_items", "rooms"
  add_foreign_key "property_items", "units"
  add_foreign_key "property_ownerships", "organizations"
  add_foreign_key "property_ownerships", "parties"
  add_foreign_key "property_ownerships", "properties"
  add_foreign_key "property_ownerships", "users", column: "verified_by_id"
  add_foreign_key "property_photos", "organizations"
  add_foreign_key "property_photos", "properties"
  add_foreign_key "property_photos", "users", column: "published_by_id"
  add_foreign_key "property_photos", "users", column: "uploaded_by_id"
  add_foreign_key "rooms", "buildings"
  add_foreign_key "rooms", "organizations"
  add_foreign_key "rooms", "properties"
  add_foreign_key "rooms", "units"
  add_foreign_key "tenant_invitations", "leases"
  add_foreign_key "tenant_invitations", "organizations"
  add_foreign_key "tenant_invitations", "parties", column: "tenant_party_id"
  add_foreign_key "tenant_invitations", "properties"
  add_foreign_key "tenant_invitations", "users", column: "accepted_user_id"
  add_foreign_key "tenant_invitations", "users", column: "invited_by_id"
  add_foreign_key "tenant_invitations", "users", column: "revoked_by_id"
  add_foreign_key "tenant_notifications", "lease_extension_requests"
  add_foreign_key "tenant_notifications", "lease_renewal_proposals"
  add_foreign_key "tenant_notifications", "leases"
  add_foreign_key "tenant_notifications", "maintenance_request_updates"
  add_foreign_key "tenant_notifications", "organizations"
  add_foreign_key "tenant_notifications", "tenant_profiles"
  add_foreign_key "tenant_profiles", "organizations"
  add_foreign_key "tenant_profiles", "party_accounts"
  add_foreign_key "units", "buildings"
  add_foreign_key "units", "organizations"
  add_foreign_key "units", "properties"
  add_foreign_key "users", "organizations"
end
