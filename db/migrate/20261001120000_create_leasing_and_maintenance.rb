class CreateLeasingAndMaintenance < ActiveRecord::Migration[8.1]
  def change
    # ── Leases ──────────────────────────────────────────────────────────────
    create_table :leases, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :property,     null: false, type: :uuid, foreign_key: true
      t.references :unit,         null: false, type: :uuid, foreign_key: true
      t.references :tenant,       null: false, type: :uuid,
                                  foreign_key: { to_table: :parties }

      t.string  :status,      null: false, default: "draft"
      t.string  :lease_type,  null: false, default: "fixed_term"

      t.date    :start_date,  null: false
      t.date    :end_date
      t.date    :signed_date

      t.decimal :monthly_rent,    precision: 15, scale: 2, null: false
      t.decimal :deposit_amount,  precision: 15, scale: 2
      t.string  :rent_currency,   default: "ZAR"

      t.integer :notice_period_days, default: 30
      t.text    :terms_summary

      t.timestamps
    end

    add_index :leases, [:organization_id, :unit_id]
    add_index :leases, [:organization_id, :status]
    add_index :leases, [:organization_id, :tenant_id]

    add_check_constraint :leases,
      "status IN ('draft','active','expired','terminated','cancelled')",
      name: "leases_status_check"

    add_check_constraint :leases,
      "lease_type IN ('fixed_term','month_to_month','periodic')",
      name: "leases_lease_type_check"

    # ── Maintenance requests ─────────────────────────────────────────────────
    create_table :maintenance_requests, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :property,     null: false, type: :uuid, foreign_key: true
      t.references :unit,         null: true,  type: :uuid, foreign_key: true
      t.references :room,         null: true,  type: :uuid, foreign_key: true
      t.references :reported_by,  null: false, type: :uuid,
                                  foreign_key: { to_table: :users }
      t.references :assigned_to,  null: true,  type: :uuid,
                                  foreign_key: { to_table: :users }

      t.string  :title,      null: false
      t.text    :description
      t.string  :category
      t.string  :priority,   null: false, default: "medium"
      t.string  :status,     null: false, default: "open"

      t.datetime :reported_at,    null: false
      t.datetime :acknowledged_at
      t.datetime :resolved_at
      t.datetime :closed_at

      t.decimal :estimated_cost,  precision: 12, scale: 2
      t.decimal :actual_cost,     precision: 12, scale: 2

      t.text    :resolution_notes

      t.timestamps
    end

    add_index :maintenance_requests, [:organization_id, :property_id]
    add_index :maintenance_requests, [:organization_id, :status]
    add_index :maintenance_requests, [:organization_id, :priority]

    add_check_constraint :maintenance_requests,
      "priority IN ('low','medium','high','urgent')",
      name: "maintenance_requests_priority_check"

    add_check_constraint :maintenance_requests,
      "status IN ('open','acknowledged','in_progress','resolved','closed','cancelled')",
      name: "maintenance_requests_status_check"

    # ── Damage assessments ───────────────────────────────────────────────────
    create_table :damage_assessments, id: :uuid do |t|
      t.references :organization,  null: false, type: :uuid, foreign_key: true
      t.references :property,      null: false, type: :uuid, foreign_key: true
      t.references :inspection,    null: true,  type: :uuid, foreign_key: true
      t.references :inspection_item, null: true, type: :uuid, foreign_key: true
      t.references :assessed_by,   null: false, type: :uuid,
                                   foreign_key: { to_table: :users }

      t.string  :severity,         null: false, default: "minor"
      t.string  :responsibility,   null: false, default: "unknown"
      t.text    :description,      null: false
      t.decimal :estimated_cost,   precision: 12, scale: 2
      t.decimal :agreed_cost,      precision: 12, scale: 2

      t.date    :assessed_on,      null: false
      t.string  :status,           null: false, default: "open"
      t.text    :resolution_notes

      t.timestamps
    end

    add_index :damage_assessments, [:organization_id, :property_id]
    add_index :damage_assessments, [:organization_id, :status]

    add_check_constraint :damage_assessments,
      "severity IN ('minor','moderate','severe','critical')",
      name: "damage_assessments_severity_check"

    add_check_constraint :damage_assessments,
      "responsibility IN ('landlord','tenant','shared','unknown')",
      name: "damage_assessments_responsibility_check"

    add_check_constraint :damage_assessments,
      "status IN ('open','under_review','agreed','disputed','resolved','written_off')",
      name: "damage_assessments_status_check"

    # ── Documents ────────────────────────────────────────────────────────────
    create_table :documents, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :uploaded_by,  null: false, type: :uuid,
                                  foreign_key: { to_table: :users }

      # polymorphic-lite: one of these is set
      t.uuid :property_id
      t.uuid :lease_id
      t.uuid :inspection_id
      t.uuid :maintenance_request_id
      t.uuid :damage_assessment_id

      t.string  :document_type,  null: false
      t.string  :title,          null: false
      t.string  :storage_key,    null: false
      t.string  :content_type
      t.integer :file_size_bytes
      t.text    :description

      t.timestamps
    end

    add_index :documents, [:organization_id, :property_id]
    add_index :documents, [:organization_id, :lease_id]
    add_index :documents, [:organization_id, :inspection_id]
    add_index :documents, [:organization_id, :document_type]

    add_check_constraint :documents,
      "property_id IS NOT NULL OR lease_id IS NOT NULL OR inspection_id IS NOT NULL OR maintenance_request_id IS NOT NULL OR damage_assessment_id IS NOT NULL",
      name: "documents_must_have_parent"

    # ── Audit logs ───────────────────────────────────────────────────────────
    create_table :audit_logs, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :actor,        null: true,  type: :uuid,
                                  foreign_key: { to_table: :users }

      t.string :auditable_type, null: false
      t.uuid   :auditable_id,   null: false
      t.string :action,         null: false
      t.jsonb  :changes_payload,             default: {}
      t.string :ip_address
      t.string :user_agent

      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :audit_logs, [:organization_id, :auditable_type, :auditable_id],
              name: "idx_audit_logs_on_org_auditable"
    add_index :audit_logs, [:organization_id, :actor_id]
    add_index :audit_logs, :occurred_at

    add_check_constraint :audit_logs,
      "action IN ('create','update','destroy','lock','unlock')",
      name: "audit_logs_action_check"
  end
end
