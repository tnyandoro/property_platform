class CreateFoundation < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :organizations, :name, unique: true

    create_table :users, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false

      t.timestamps
    end

    add_index :users,
              [:organization_id, :email],
              unique: true

    create_table :parties, id: :uuid do |t|
      t.references :organization,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.string :party_type, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :parties,
              [:organization_id, :party_type]
  end
end