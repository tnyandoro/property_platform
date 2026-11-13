class AddTenantIdentityFoundation < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :organization_role, :string, null: false, default: "member"
    add_column :users, :email_verified_at, :datetime
    add_check_constraint :users,
      "organization_role IN ('member', 'administrator')",
      name: "users_organization_role_check"

    add_column :property_assignments, :capabilities, :string, array: true, null: false, default: []
    add_check_constraint :property_assignments,
      "capabilities <@ ARRAY['invite_tenants', 'propose_lease_renewals', 'publish_tenant_information']::character varying[]",
      name: "property_assignments_capabilities_check"

    create_table :party_accounts, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :party, null: false, type: :uuid, foreign_key: true
      t.references :verified_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :revoked_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending_verification"
      t.datetime :verified_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :party_accounts, [:organization_id, :user_id, :party_id],
      unique: true,
      name: "idx_party_accounts_org_user_party"
    add_check_constraint :party_accounts,
      "status IN ('pending_verification', 'verified', 'revoked')",
      name: "party_accounts_status_check"
    add_check_constraint :party_accounts,
      "(verified_at IS NULL) = (verified_by_id IS NULL)",
      name: "party_accounts_verification_metadata_check"
    add_check_constraint :party_accounts,
      "(revoked_at IS NULL) = (revoked_by_id IS NULL)",
      name: "party_accounts_revocation_metadata_check"
    add_check_constraint :party_accounts,
      "(status <> 'verified' OR verified_at IS NOT NULL) AND (status <> 'revoked' OR revoked_at IS NOT NULL)",
      name: "party_accounts_status_metadata_check"

    create_table :tenant_profiles, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :party_account, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.string :tenant_reference
      t.string :phone_number
      t.timestamps
    end

    add_index :tenant_profiles, [:organization_id, :tenant_reference],
      unique: true,
      where: "tenant_reference IS NOT NULL",
      name: "idx_tenant_profiles_org_reference"

    create_table :platform_administrator_grants, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :granted_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :revoked_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :reason, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :platform_administrator_grants, :user_id,
      unique: true,
      where: "revoked_at IS NULL",
      name: "idx_platform_admin_grants_active_user"
    add_check_constraint :platform_administrator_grants,
      "(revoked_at IS NULL) = (revoked_by_id IS NULL)",
      name: "platform_admin_grants_revocation_metadata_check"
  end
end
