class AddOwnershipTransactionDetails < ActiveRecord::Migration[8.1]
  def up
    add_column :property_ownerships, :valuation_at_transfer, :decimal, precision: 15, scale: 2
    add_column :property_ownerships, :currency, :string
    add_column :property_ownerships, :transfer_reference, :string
    add_column :property_ownerships, :conveyancer, :string
    add_column :property_ownerships, :verification_status, :string, null: false, default: "unverified"
    add_column :property_ownerships, :verified_at, :datetime
    add_reference :property_ownerships, :verified_by, type: :uuid, foreign_key: { to_table: :users }

    add_index :property_ownerships, [:property_id, :start_date], name: "index_property_ownerships_on_property_and_start_date"
    add_index :property_ownerships, [:organization_id, :transfer_reference], name: "index_property_ownerships_on_org_and_transfer_reference"
    add_check_constraint :property_ownerships,
      "verification_status IN ('unverified', 'pending_review', 'verified')",
      name: "property_ownerships_verification_status_check"

    add_reference :documents, :property_ownership, type: :uuid, foreign_key: true
    add_index :documents, [:organization_id, :property_ownership_id], name: "index_documents_on_org_and_property_ownership"

    remove_check_constraint :documents, name: "documents_must_have_parent"
    add_check_constraint :documents,
      "property_id IS NOT NULL OR lease_id IS NOT NULL OR inspection_id IS NOT NULL OR maintenance_request_id IS NOT NULL OR damage_assessment_id IS NOT NULL OR property_ownership_id IS NOT NULL",
      name: "documents_must_have_parent"
  end

  def down
    remove_check_constraint :documents, name: "documents_must_have_parent"
    add_check_constraint :documents,
      "property_id IS NOT NULL OR lease_id IS NOT NULL OR inspection_id IS NOT NULL OR maintenance_request_id IS NOT NULL OR damage_assessment_id IS NOT NULL",
      name: "documents_must_have_parent"

    remove_index :documents, name: "index_documents_on_org_and_property_ownership"
    remove_reference :documents, :property_ownership, foreign_key: true

    remove_check_constraint :property_ownerships, name: "property_ownerships_verification_status_check"
    remove_index :property_ownerships, name: "index_property_ownerships_on_property_and_start_date"
    remove_index :property_ownerships, name: "index_property_ownerships_on_org_and_transfer_reference"
    remove_reference :property_ownerships, :verified_by, foreign_key: { to_table: :users }
    remove_column :property_ownerships, :verified_at
    remove_column :property_ownerships, :verification_status
    remove_column :property_ownerships, :conveyancer
    remove_column :property_ownerships, :transfer_reference
    remove_column :property_ownerships, :currency
    remove_column :property_ownerships, :valuation_at_transfer
  end
end
