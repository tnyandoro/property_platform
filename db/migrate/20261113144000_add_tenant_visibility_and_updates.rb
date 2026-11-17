class AddTenantVisibilityAndUpdates < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :visibility, :string, null: false, default: "internal"
    add_column :documents, :published_at, :datetime
    add_reference :documents, :published_by, type: :uuid, foreign_key: { to_table: :users }
    add_check_constraint :documents,
      "visibility IN ('internal', 'tenant_visible')",
      name: "documents_visibility_check"
    add_check_constraint :documents,
      "visibility <> 'tenant_visible' OR (published_at IS NOT NULL AND published_by_id IS NOT NULL)",
      name: "documents_publication_metadata_check"

    create_table :property_photos, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :property, null: false, type: :uuid, foreign_key: true
      t.references :uploaded_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :published_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :caption
      t.string :visibility, null: false, default: "internal"
      t.integer :position, null: false, default: 0
      t.datetime :published_at
      t.timestamps
    end

    add_index :property_photos, [:organization_id, :property_id, :visibility, :position],
      name: "idx_property_photos_tenant_visibility"
    add_check_constraint :property_photos,
      "visibility IN ('internal', 'tenant_visible') AND position >= 0",
      name: "property_photos_visibility_position_check"
    add_check_constraint :property_photos,
      "visibility <> 'tenant_visible' OR (published_at IS NOT NULL AND published_by_id IS NOT NULL)",
      name: "property_photos_publication_metadata_check"

    create_table :maintenance_request_updates, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :maintenance_request, null: false, type: :uuid, foreign_key: true
      t.references :author, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :published_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :update_type, null: false, default: "update"
      t.string :status, null: false, default: "draft"
      t.text :body, null: false
      t.datetime :scheduled_start_at
      t.datetime :scheduled_end_at
      t.datetime :completed_at
      t.datetime :published_at
      t.timestamps
    end

    add_index :maintenance_request_updates, [:organization_id, :maintenance_request_id, :status],
      name: "idx_maintenance_updates_request_status"
    add_check_constraint :maintenance_request_updates,
      "update_type IN ('status', 'update', 'scheduled_visit', 'completion')",
      name: "maintenance_request_updates_type_check"
    add_check_constraint :maintenance_request_updates,
      "status IN ('draft', 'published', 'withdrawn')",
      name: "maintenance_request_updates_status_check"
    add_check_constraint :maintenance_request_updates,
      "(scheduled_start_at IS NULL OR scheduled_end_at IS NULL OR scheduled_end_at >= scheduled_start_at) AND (status <> 'published' OR (published_at IS NOT NULL AND published_by_id IS NOT NULL))",
      name: "maintenance_request_updates_timing_publication_check"

    create_table :tenant_notifications, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :tenant_profile, null: false, type: :uuid, foreign_key: true
      t.references :lease, type: :uuid, foreign_key: true
      t.references :lease_renewal_proposal, type: :uuid, foreign_key: true
      t.references :lease_extension_request, type: :uuid, foreign_key: true
      t.references :maintenance_request_update, type: :uuid, foreign_key: true
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :read_at
      t.timestamps
    end

    add_index :tenant_notifications, [:organization_id, :tenant_profile_id, :created_at],
      name: "idx_tenant_notifications_profile"
    add_check_constraint :tenant_notifications,
      "num_nonnulls(lease_id, lease_renewal_proposal_id, lease_extension_request_id, maintenance_request_update_id) = 1",
      name: "tenant_notifications_single_source_check"
    add_check_constraint :tenant_notifications,
      "notification_type IN ('lease_expiring', 'lease_renewal_proposal', 'lease_extension_request', 'maintenance_request_update')",
      name: "tenant_notifications_type_check"
  end
end
