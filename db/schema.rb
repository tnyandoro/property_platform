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

ActiveRecord::Schema[8.1].define(version: 2026_08_12_152933) do
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
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.decimal "current_value", precision: 15, scale: 2
    t.text "description"
    t.integer "expected_lifespan_years"
    t.string "item_type", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.date "purchase_date"
    t.decimal "purchase_value", precision: 15, scale: 2
    t.decimal "replacement_value", precision: 15, scale: 2
    t.uuid "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "item_type"], name: "index_property_items_on_organization_id_and_item_type"
    t.index ["organization_id", "room_id"], name: "index_property_items_on_organization_id_and_room_id"
    t.index ["organization_id"], name: "index_property_items_on_organization_id"
    t.index ["room_id"], name: "index_property_items_on_room_id"
  end

  create_table "property_ownerships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.text "notes"
    t.uuid "organization_id", null: false
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
  end

  create_table "rooms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "floor_number"
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.string "room_type", null: false
    t.decimal "size", precision: 10, scale: 2
    t.uuid "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "unit_id"], name: "index_rooms_on_organization_id_and_unit_id"
    t.index ["organization_id"], name: "index_rooms_on_organization_id"
    t.index ["unit_id"], name: "index_rooms_on_unit_id"
  end

  create_table "units", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "bathrooms", default: 0, null: false
    t.integer "bedrooms", default: 0, null: false
    t.uuid "building_id", null: false
    t.string "condition"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.uuid "organization_id", null: false
    t.decimal "size", precision: 12, scale: 2
    t.string "unit_number"
    t.string "unit_type"
    t.datetime "updated_at", null: false
    t.index ["building_id"], name: "index_units_on_building_id"
    t.index ["organization_id", "building_id"], name: "index_units_on_organization_id_and_building_id"
    t.index ["organization_id"], name: "index_units_on_organization_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "buildings", "organizations"
  add_foreign_key "buildings", "properties"
  add_foreign_key "parties", "organizations"
  add_foreign_key "properties", "organizations"
  add_foreign_key "property_assignments", "organizations"
  add_foreign_key "property_assignments", "properties"
  add_foreign_key "property_assignments", "users"
  add_foreign_key "property_items", "organizations"
  add_foreign_key "property_items", "rooms"
  add_foreign_key "property_ownerships", "organizations"
  add_foreign_key "property_ownerships", "parties"
  add_foreign_key "property_ownerships", "properties"
  add_foreign_key "rooms", "organizations"
  add_foreign_key "rooms", "units"
  add_foreign_key "units", "buildings"
  add_foreign_key "units", "organizations"
  add_foreign_key "users", "organizations"
end
