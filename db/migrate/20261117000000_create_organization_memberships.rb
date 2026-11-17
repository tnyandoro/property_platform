class CreateOrganizationMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :organization_memberships, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :role, null: false, default: "member"
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    add_index :organization_memberships,
              [ :organization_id, :user_id ],
              unique: true,
              name: "idx_organization_memberships_org_user"
    add_index :organization_memberships, [ :user_id, :status ]

    add_check_constraint :organization_memberships,
                         "status IN ('active', 'suspended', 'revoked')",
                         name: "organization_memberships_status_check"

    add_check_constraint :organization_memberships,
                         "role IN ('member', 'administrator')",
                         name: "organization_memberships_role_check"

    execute <<~SQL
      INSERT INTO organization_memberships
        (id, organization_id, user_id, role, status, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        users.organization_id,
        users.id,
        COALESCE(NULLIF(users.organization_role, ''), 'member'),
        'active',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM users
    SQL
  end

  def down
    drop_table :organization_memberships
  end
end
