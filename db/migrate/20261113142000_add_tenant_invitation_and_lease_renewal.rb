class AddTenantInvitationAndLeaseRenewal < ActiveRecord::Migration[8.1]
  def change
    add_reference :leases, :previous_lease, type: :uuid,
      foreign_key: { to_table: :leases }, index: { unique: true }

    create_table :tenant_invitations, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :tenant_party, null: false, type: :uuid, foreign_key: { to_table: :parties }
      t.references :property, null: false, type: :uuid, foreign_key: true
      t.references :lease, null: false, type: :uuid, foreign_key: true
      t.references :invited_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :accepted_user, type: :uuid, foreign_key: { to_table: :users }
      t.references :revoked_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :target_email, null: false
      t.string :token_digest, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.datetime :expired_at
      t.timestamps
    end

    add_index :tenant_invitations, :token_digest, unique: true
    add_index :tenant_invitations, [:organization_id, :lease_id, :target_email],
      unique: true,
      where: "status = 'pending'",
      name: "idx_tenant_invitations_pending_email"
    add_check_constraint :tenant_invitations,
      "status IN ('pending', 'accepted', 'revoked', 'expired')",
      name: "tenant_invitations_status_check"
    add_check_constraint :tenant_invitations,
      "(accepted_at IS NULL) = (accepted_user_id IS NULL)",
      name: "tenant_invitations_acceptance_metadata_check"
    add_check_constraint :tenant_invitations,
      "(revoked_at IS NULL) = (revoked_by_id IS NULL)",
      name: "tenant_invitations_revocation_metadata_check"
    add_check_constraint :tenant_invitations,
      "(status <> 'accepted' OR accepted_at IS NOT NULL) AND (status <> 'revoked' OR revoked_at IS NOT NULL) AND (status <> 'expired' OR expired_at IS NOT NULL)",
      name: "tenant_invitations_status_metadata_check"

    create_table :lease_renewal_proposals, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :lease, null: false, type: :uuid, foreign_key: true
      t.references :created_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :responded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :resulting_lease, type: :uuid, foreign_key: { to_table: :leases }, index: { unique: true }
      t.references :document, type: :uuid, foreign_key: true
      t.integer :version_number, null: false
      t.date :proposed_start_date, null: false
      t.date :proposed_end_date, null: false
      t.decimal :proposed_monthly_rent, precision: 15, scale: 2, null: false
      t.string :rent_currency, null: false, default: "ZAR"
      t.text :proposed_terms
      t.string :status, null: false, default: "draft"
      t.datetime :expires_at
      t.datetime :responded_at
      t.string :response_notes
      t.timestamps
    end

    add_index :lease_renewal_proposals, [:lease_id, :version_number],
      unique: true,
      name: "idx_lease_renewal_proposals_version"
    add_check_constraint :lease_renewal_proposals,
      "version_number > 0 AND proposed_end_date >= proposed_start_date AND proposed_monthly_rent >= 0",
      name: "lease_renewal_proposals_terms_check"
    add_check_constraint :lease_renewal_proposals,
      "rent_currency ~ '^[A-Z]{3}$'",
      name: "lease_renewal_proposals_currency_check"
    add_check_constraint :lease_renewal_proposals,
      "status IN ('draft', 'offered', 'accepted', 'rejected', 'expired', 'withdrawn')",
      name: "lease_renewal_proposals_status_check"
    add_check_constraint :lease_renewal_proposals,
      "(responded_at IS NULL) = (responded_by_id IS NULL) OR status = 'expired'",
      name: "lease_renewal_proposals_response_metadata_check"

    create_table :lease_extension_requests, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :lease, null: false, type: :uuid, foreign_key: true
      t.references :tenant_profile, null: false, type: :uuid, foreign_key: true
      t.references :requested_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :responded_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :lease_renewal_proposal, type: :uuid, foreign_key: true
      t.date :requested_end_date
      t.text :message
      t.string :status, null: false, default: "pending"
      t.datetime :responded_at
      t.text :response_notes
      t.timestamps
    end

    add_index :lease_extension_requests, [:organization_id, :lease_id, :status],
      name: "idx_lease_extension_requests_scope"
    add_check_constraint :lease_extension_requests,
      "status IN ('pending', 'proposal_created', 'rejected', 'withdrawn', 'closed')",
      name: "lease_extension_requests_status_check"
    add_check_constraint :lease_extension_requests,
      "(responded_at IS NULL) = (responded_by_id IS NULL)",
      name: "lease_extension_requests_response_metadata_check"
  end
end
