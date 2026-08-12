class CreatePropertyRegistry < ActiveRecord::Migration[8.1]
  def change
    create_table :properties, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :name, null: false
      t.string :property_type, null: false
      t.string :property_subtype

      t.integer :year_established

      t.decimal :land_size, precision: 12, scale: 2
      t.decimal :building_size, precision: 12, scale: 2

      t.decimal :original_value, precision: 15, scale: 2
      t.decimal :current_value, precision: 15, scale: 2

      t.string :address_line_1
      t.string :address_line_2
      t.string :suburb
      t.string :city
      t.string :province
      t.string :postal_code
      t.string :country

      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7

      t.string :condition
      t.text :description

      t.integer :cached_total_units, default: 0, null: false
      t.integer :cached_total_bedrooms, default: 0, null: false

      t.timestamps
    end

    add_index :properties,
              [:organization_id, :name]

    create_table :property_ownerships, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :property,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :party,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.date :start_date, null: false
      t.date :end_date

      t.string :transfer_type
      t.decimal :transfer_value, precision: 15, scale: 2

      t.text :notes

      t.timestamps
    end

    add_index :property_ownerships,
              [:organization_id, :property_id]

    add_index :property_ownerships,
              [:organization_id, :party_id]

    create_table :buildings, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :property,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :name, null: false
      t.string :building_type

      t.text :description

      t.timestamps
    end

    add_index :buildings,
              [:organization_id, :property_id]

    create_table :units, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :building,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :unit_number
      t.string :name

      t.string :unit_type

      t.integer :bedrooms, default: 0, null: false
      t.integer :bathrooms, default: 0, null: false

      t.decimal :size, precision: 12, scale: 2

      t.string :condition
      t.text :description

      t.timestamps
    end

    add_index :units,
              [:organization_id, :building_id]

    create_table :rooms, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :unit,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :name, null: false
      t.string :room_type, null: false

      t.decimal :size, precision: 10, scale: 2

      t.integer :floor_number

      t.text :description

      t.timestamps
    end

    add_index :rooms,
              [:organization_id, :unit_id]

    create_table :property_items, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :room,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :name, null: false
      t.string :item_type, null: false

      t.text :description

      t.decimal :purchase_value, precision: 15, scale: 2
      t.decimal :current_value, precision: 15, scale: 2
      t.decimal :replacement_value, precision: 15, scale: 2

      t.date :purchase_date
      t.integer :expected_lifespan_years

      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :property_items,
              [:organization_id, :room_id]

    add_index :property_items,
              [:organization_id, :item_type]

    create_table :property_assignments, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :property,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :user,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :assignment_type, null: false

      t.datetime :starts_at, null: false
      t.datetime :ends_at

      t.timestamps
    end

    add_index :property_assignments,
              [:organization_id, :property_id, :user_id],
              unique: true,
              name: "idx_property_assignments_scope"

    add_index :property_assignments,
              [:organization_id, :property_id]
  end
end