class ExtendMaintenanceManagement < ActiveRecord::Migration[8.1]
  def change
    create_table :maintenance_schedules, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :property, null: false, type: :uuid, foreign_key: true
      t.references :unit, type: :uuid, foreign_key: true
      t.references :assigned_to, type: :uuid, foreign_key: { to_table: :users }
      t.references :contractor, type: :uuid, foreign_key: { to_table: :parties }
      t.references :created_by, null: false, type: :uuid, foreign_key: { to_table: :users }

      t.string :title, null: false
      t.text :description
      t.string :category
      t.string :priority, null: false, default: "medium"
      t.string :classification, null: false, default: "undetermined"
      t.string :suggested_responsibility, null: false, default: "pending"
      t.string :frequency, null: false, default: "once"
      t.integer :interval_months
      t.date :starts_on, null: false
      t.date :ends_on
      t.date :next_due_on, null: false
      t.integer :reminder_days, null: false, default: 7
      t.string :status, null: false, default: "active"
      t.string :generation_mode, null: false, default: "proposed"
      t.decimal :estimated_cost, precision: 12, scale: 2
      t.string :currency, null: false, default: "ZAR"
      t.timestamps
    end

    add_index :maintenance_schedules, [:organization_id, :property_id, :status],
      name: "idx_maint_sched_org_property_status"
    add_check_constraint :maintenance_schedules,
      "priority IN ('low','medium','high','urgent')",
      name: "maintenance_schedules_priority_check"
    add_check_constraint :maintenance_schedules,
      "classification IN ('wear_and_tear','accidental_damage','negligence','misuse','structural_deterioration','preventative_maintenance','breakdown','improvement','compliance_safety','other','undetermined')",
      name: "maintenance_schedules_classification_check"
    add_check_constraint :maintenance_schedules,
      "suggested_responsibility IN ('owner','tenant','shared','other','pending')",
      name: "maintenance_schedules_responsibility_check"
    add_check_constraint :maintenance_schedules,
      "frequency IN ('once','monthly','quarterly','semi_annual','annual','custom')",
      name: "maintenance_schedules_frequency_check"
    add_check_constraint :maintenance_schedules,
      "status IN ('active','paused','completed')",
      name: "maintenance_schedules_status_check"
    add_check_constraint :maintenance_schedules,
      "generation_mode IN ('automatic','proposed','reminder_only')",
      name: "maintenance_schedules_generation_mode_check"
    add_check_constraint :maintenance_schedules,
      "estimated_cost IS NULL OR estimated_cost >= 0",
      name: "maintenance_schedules_estimated_cost_check"
    add_check_constraint :maintenance_schedules,
      "interval_months IS NULL OR interval_months > 0",
      name: "maintenance_schedules_interval_months_check"
    add_check_constraint :maintenance_schedules,
      "reminder_days >= 0",
      name: "maintenance_schedules_reminder_days_check"

    add_reference :maintenance_requests, :lease, type: :uuid, foreign_key: true
    add_reference :maintenance_requests, :contractor, type: :uuid, foreign_key: { to_table: :parties }
    add_reference :maintenance_requests, :source_inspection, type: :uuid, foreign_key: { to_table: :inspections }
    add_reference :maintenance_requests, :source_inspection_item, type: :uuid, foreign_key: { to_table: :inspection_items }, index: false
    add_reference :maintenance_requests, :source_damage_assessment, type: :uuid, foreign_key: { to_table: :damage_assessments }, index: false
    add_reference :maintenance_requests, :maintenance_schedule, type: :uuid, foreign_key: true, index: false
    add_reference :maintenance_requests, :approved_by, type: :uuid, foreign_key: { to_table: :users }
    add_reference :maintenance_requests, :responsibility_reviewed_by, type: :uuid, foreign_key: { to_table: :users }
    add_reference :maintenance_requests, :closed_by, type: :uuid, foreign_key: { to_table: :users }

    add_column :maintenance_requests, :classification, :string, null: false, default: "undetermined"
    add_column :maintenance_requests, :responsibility_status, :string, null: false, default: "pending_review"
    add_column :maintenance_requests, :responsibility_notes, :text
    add_column :maintenance_requests, :approval_notes, :text
    add_column :maintenance_requests, :rejection_reason, :text
    add_column :maintenance_requests, :cancellation_reason, :text
    add_column :maintenance_requests, :source_type, :string, null: false, default: "manager"
    add_column :maintenance_requests, :scheduled_on, :date
    add_column :maintenance_requests, :target_completion_on, :date
    add_column :maintenance_requests, :actual_started_at, :datetime
    add_column :maintenance_requests, :occurrence_on, :date
    add_column :maintenance_requests, :approved_cost, :decimal, precision: 12, scale: 2
    add_column :maintenance_requests, :currency, :string, null: false, default: "ZAR"
    add_column :maintenance_requests, :approved_at, :datetime
    add_column :maintenance_requests, :responsibility_reviewed_at, :datetime

    remove_check_constraint :maintenance_requests, name: "maintenance_requests_status_check"
    add_check_constraint :maintenance_requests,
      "status IN ('open','acknowledged','awaiting_approval','approved','scheduled','in_progress','resolved','closed','rejected','disputed','cancelled')",
      name: "maintenance_requests_status_check"
    add_check_constraint :maintenance_requests,
      "classification IN ('wear_and_tear','accidental_damage','negligence','misuse','structural_deterioration','preventative_maintenance','breakdown','improvement','compliance_safety','other','undetermined')",
      name: "maintenance_requests_classification_check"
    add_check_constraint :maintenance_requests,
      "responsibility_status IN ('pending_review','approved','disputed')",
      name: "maintenance_requests_responsibility_status_check"
    add_check_constraint :maintenance_requests,
      "source_type IN ('tenant_request','schedule','inspection','damage_assessment','manager','other')",
      name: "maintenance_requests_source_type_check"
    add_check_constraint :maintenance_requests,
      "(estimated_cost IS NULL OR estimated_cost >= 0) AND (approved_cost IS NULL OR approved_cost >= 0) AND (actual_cost IS NULL OR actual_cost >= 0)",
      name: "maintenance_requests_costs_check"

    add_index :maintenance_requests, [:maintenance_schedule_id, :occurrence_on],
      unique: true,
      where: "maintenance_schedule_id IS NOT NULL AND occurrence_on IS NOT NULL",
      name: "idx_maintenance_requests_schedule_occurrence"
    add_index :maintenance_requests, :source_inspection_item_id,
      unique: true,
      where: "source_inspection_item_id IS NOT NULL",
      name: "idx_maint_req_source_inspection_item"
    add_index :maintenance_requests, :source_damage_assessment_id,
      unique: true,
      where: "source_damage_assessment_id IS NOT NULL",
      name: "idx_maint_req_source_damage_assessment"
    add_index :documents, :maintenance_request_id

    create_table :maintenance_cost_allocations, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :maintenance_request, null: false, type: :uuid, foreign_key: true
      t.references :party, type: :uuid, foreign_key: true
      t.references :approved_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :responsible_party, null: false
      t.string :status, null: false, default: "approved"
      t.decimal :allocated_amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.text :rationale, null: false
      t.timestamps
    end

    add_index :maintenance_cost_allocations, [:organization_id, :maintenance_request_id],
      name: "idx_maint_alloc_org_request"
    add_check_constraint :maintenance_cost_allocations,
      "responsible_party IN ('owner','tenant','shared','other')",
      name: "maintenance_cost_allocations_party_check"
    add_check_constraint :maintenance_cost_allocations,
      "status IN ('approved','superseded')",
      name: "maintenance_cost_allocations_status_check"
    add_check_constraint :maintenance_cost_allocations,
      "allocated_amount >= 0",
      name: "maintenance_cost_allocations_amount_check"

    create_table :maintenance_financial_entries, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :maintenance_request, null: false, type: :uuid, foreign_key: true
      t.references :party, type: :uuid, foreign_key: true
      t.references :recorded_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :entry_type, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.date :occurred_on, null: false
      t.string :reference
      t.text :notes
      t.timestamps
    end

    add_index :maintenance_financial_entries, [:organization_id, :maintenance_request_id, :entry_type],
      name: "idx_maint_finance_org_req_type"
    add_check_constraint :maintenance_financial_entries,
      "entry_type IN ('quotation','invoice','payment')",
      name: "maintenance_financial_entries_type_check"
    add_check_constraint :maintenance_financial_entries,
      "amount >= 0",
      name: "maintenance_financial_entries_amount_check"
  end
end
