class CreateAccessTokenRevocations < ActiveRecord::Migration[8.1]
  def change
    create_table :access_token_revocations, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :token_id, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :access_token_revocations, :token_id, unique: true
    add_index :access_token_revocations, [ :user_id, :expires_at ]
    add_index :access_token_revocations, :expires_at
  end
end
