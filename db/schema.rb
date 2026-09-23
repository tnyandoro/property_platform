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

ActiveRecord::Schema[8.1].define(version: 2026_09_23_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

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

  create_table "properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address_line_1"
    t.string "address_line_2"
    t.decimal "building_size", precision: 12, scale: 2
    t.integer "cached_total_bedrooms", default: 0, null: false
    t.integer "cached_total_units", default: 0, null: false
    t.string "city"
    t.string "condition"
    t.string "country"
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
    t.datetime "created_at", null: false
    t.date "end_date"
    t.text "notes"
    t.uuid "organization_id", null: false
    t.decimal "ownership_percentage", precision: 5, scale: 2, null: false
    t.uuid "party_id", null: false
    t.uuid "property_id", null: false
    t.date "start_date", null: false
    t.string "transfer_type"
    t.decimal "transfer_value", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.index ["organization_id", "party_id"], name: "index_property_ownerships_on_organization_id_and_party_id"
    t.index ["organization_id", "property_id"], name: "index_property_ownerships_on_organization_id_and_property_id"
    t.index ["organization_id"], name: "index_property_ownerships_on_organization_id"
    t.index ["party_id"], name: "index_property_ownerships_on_party_id"
    t.index ["property_id"], name: "index_property_ownerships_on_property_id"
    t.check_constraint "ownership_percentage > 0::numeric AND ownership_percentage <= 100::numeric", name: "property_ownerships_ownership_percentage_range"
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
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.uuid "organization_id", null: false
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "buildings", "organizations"
  add_foreign_key "buildings", "properties"
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
  add_foreign_key "parties", "organizations"
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
  add_foreign_key "rooms", "buildings"
  add_foreign_key "rooms", "organizations"
  add_foreign_key "rooms", "properties"
  add_foreign_key "rooms", "units"
  add_foreign_key "units", "buildings"
  add_foreign_key "units", "organizations"
  add_foreign_key "units", "properties"
  add_foreign_key "users", "organizations"
end
