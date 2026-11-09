class CreateInspectionEngine < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_amendments, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :inspection,   null: false, type: :uuid, foreign_key: true
      t.references :inspection_item, null: false, type: :uuid, foreign_key: true

      t.references :amended_by, null: false, type: :uuid,
                                foreign_key: { to_table: :users }

      t.string :field_name,     null: false
      t.text   :original_value
      t.text   :amended_value,  null: false
      t.text   :reason

      t.timestamps
    end

    add_index :inspection_amendments,
              [:organization_id, :inspection_id],
              name: "idx_on_organization_id_inspection_id_455883dfcc"

    add_index :inspection_amendments,
              [:organization_id, :inspection_item_id],
              name: "idx_on_organization_id_inspection_item_id_7a7c08c8f1"

    create_table :inspection_photos, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :inspection,   null: false, type: :uuid, foreign_key: true

      # nullable FKs — check constraint enforces at least one is set
      t.uuid :inspection_room_id
      t.uuid :inspection_item_id

      t.string   :storage_key,  null: false
      t.string   :content_type
      t.text     :caption
      t.datetime :taken_at

      t.timestamps
    end

    add_foreign_key :inspection_photos, :inspection_rooms
    add_foreign_key :inspection_photos, :inspection_items

    add_index :inspection_photos, :inspection_room_id
    add_index :inspection_photos, :inspection_item_id

    add_index :inspection_photos,
              [:organization_id, :inspection_id],
              name: "index_inspection_photos_on_organization_id_and_inspection_id"

    add_check_constraint :inspection_photos,
                         "inspection_room_id IS NOT NULL OR inspection_item_id IS NOT NULL",
                         name: "inspection_photos_must_have_parent"
  end
end
