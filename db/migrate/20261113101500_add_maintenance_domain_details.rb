class AddMaintenanceDomainDetails < ActiveRecord::Migration[8.1]
  def up
    abort_if_orphaned_maintenance_documents
    abort_if_invalid_custom_schedules

    add_column :maintenance_requests, :suggested_responsibility, :string, null: false, default: "unknown"
    add_reference :maintenance_requests, :rejected_by, type: :uuid, foreign_key: { to_table: :users }
    add_reference :maintenance_requests, :verified_by, type: :uuid, foreign_key: { to_table: :users }
    add_column :maintenance_requests, :rejected_at, :datetime
    add_column :maintenance_requests, :verified_at, :datetime
    add_check_constraint :maintenance_requests,
      "suggested_responsibility IN ('owner','tenant','shared','organization','third_party','unknown')",
      name: "maintenance_requests_suggested_responsibility_check"

    add_column :maintenance_cost_allocations, :allocation_percentage, :decimal, precision: 5, scale: 2
    add_column :maintenance_cost_allocations, :approved_at, :datetime
    add_reference :maintenance_cost_allocations, :lease, type: :uuid, foreign_key: true
    add_reference :maintenance_cost_allocations, :property_ownership, type: :uuid, foreign_key: true
    remove_check_constraint :maintenance_cost_allocations, name: "maintenance_cost_allocations_party_check"
    add_check_constraint :maintenance_cost_allocations,
      "responsible_party IN ('owner','tenant','shared','other','organization','third_party')",
      name: "maintenance_cost_allocations_party_check"
    add_check_constraint :maintenance_cost_allocations,
      "allocation_percentage IS NULL OR allocation_percentage BETWEEN 0 AND 100",
      name: "maintenance_cost_allocations_percentage_check"

    add_column :maintenance_financial_entries, :type, :string
    add_column :maintenance_financial_entries, :status, :string, null: false, default: "recorded"
    add_column :maintenance_financial_entries, :valid_until, :date
    add_column :maintenance_financial_entries, :due_on, :date
    add_column :maintenance_financial_entries, :invoice_reference, :string
    add_column :maintenance_financial_entries, :decision_at, :datetime
    add_column :maintenance_financial_entries, :decision_reason, :text
    add_reference :maintenance_financial_entries, :decision_by, type: :uuid, foreign_key: { to_table: :users }
    add_reference :maintenance_financial_entries, :invoice, type: :uuid,
      foreign_key: { to_table: :maintenance_financial_entries }
    add_check_constraint :maintenance_financial_entries,
      "type IS NULL OR type IN ('MaintenanceQuote','MaintenanceInvoice','MaintenancePayment')",
      name: "maintenance_financial_entries_sti_type_check"
    add_check_constraint :maintenance_financial_entries,
      "type IS NULL OR (type = 'MaintenanceQuote' AND entry_type = 'quotation') OR " \
      "(type = 'MaintenanceInvoice' AND entry_type = 'invoice') OR " \
      "(type = 'MaintenancePayment' AND entry_type = 'payment')",
      name: "maintenance_financial_entries_sti_entry_type_check"
    add_check_constraint :maintenance_financial_entries,
      "(type IS NULL AND invoice_id IS NULL) OR " \
      "(type = 'MaintenancePayment' AND invoice_id IS NOT NULL) OR " \
      "(type IN ('MaintenanceQuote','MaintenanceInvoice') AND invoice_id IS NULL)",
      name: "maintenance_financial_entries_payment_invoice_check"
    add_check_constraint :maintenance_financial_entries,
      "status IN ('recorded','draft','received','selected','rejected','expired','superseded'," \
      "'approved','partially_paid','paid','overdue','disputed','cancelled','pending','failed')",
      name: "maintenance_financial_entries_status_check"
    add_index :maintenance_financial_entries, :maintenance_request_id,
      unique: true,
      where: "type = 'MaintenanceQuote' AND status = 'selected'",
      name: "idx_maintenance_entries_one_selected_quote"
    add_index :maintenance_financial_entries,
      [:organization_id, :party_id, :invoice_reference],
      unique: true,
      where: "type = 'MaintenanceInvoice' AND invoice_reference IS NOT NULL AND invoice_reference <> ''",
      name: "idx_maintenance_invoice_reference"

    add_reference :documents, :maintenance_financial_entry, type: :uuid,
      foreign_key: { to_table: :maintenance_financial_entries }
    remove_check_constraint :documents, name: "documents_must_have_parent"
    add_check_constraint :documents,
      "property_id IS NOT NULL OR lease_id IS NOT NULL OR inspection_id IS NOT NULL OR " \
      "maintenance_request_id IS NOT NULL OR maintenance_financial_entry_id IS NOT NULL OR " \
      "damage_assessment_id IS NOT NULL OR property_ownership_id IS NOT NULL",
      name: "documents_must_have_parent"
    add_foreign_key :documents, :maintenance_requests, column: :maintenance_request_id unless
      foreign_key_exists?(:documents, :maintenance_requests, column: :maintenance_request_id)

    add_reference :maintenance_schedules, :room, type: :uuid, foreign_key: true
    add_column :maintenance_schedules, :interval_value, :integer
    add_column :maintenance_schedules, :interval_unit, :string
    remove_check_constraint :maintenance_schedules, name: "maintenance_schedules_frequency_check"
    add_check_constraint :maintenance_schedules,
      "frequency IN ('once','daily','weekly','monthly','quarterly','semi_annual','annual','custom')",
      name: "maintenance_schedules_frequency_check"
    remove_check_constraint :maintenance_schedules, name: "maintenance_schedules_responsibility_check"
    add_check_constraint :maintenance_schedules,
      "suggested_responsibility IN ('owner','tenant','shared','other','pending','organization','third_party','unknown')",
      name: "maintenance_schedules_responsibility_check"
    add_check_constraint :maintenance_schedules,
      "interval_value IS NULL OR interval_value > 0",
      name: "maintenance_schedules_interval_value_check"
    add_check_constraint :maintenance_schedules,
      "interval_unit IS NULL OR interval_unit IN ('day','week','month')",
      name: "maintenance_schedules_interval_unit_check"
    add_check_constraint :maintenance_schedules,
      "frequency <> 'custom' OR interval_months IS NOT NULL OR " \
      "(interval_value IS NOT NULL AND interval_unit IS NOT NULL)",
      name: "maintenance_schedules_custom_interval_check"
  end

  def down
    abort_if_phase2_domain_data_exists

    remove_check_constraint :maintenance_schedules, name: "maintenance_schedules_custom_interval_check"
    remove_check_constraint :maintenance_schedules, name: "maintenance_schedules_interval_unit_check"
    remove_check_constraint :maintenance_schedules, name: "maintenance_schedules_interval_value_check"
    remove_check_constraint :maintenance_schedules, name: "maintenance_schedules_responsibility_check"
    remove_check_constraint :maintenance_schedules, name: "maintenance_schedules_frequency_check"
    add_check_constraint :maintenance_schedules,
      "suggested_responsibility IN ('owner','tenant','shared','other','pending')",
      name: "maintenance_schedules_responsibility_check"
    add_check_constraint :maintenance_schedules,
      "frequency IN ('once','monthly','quarterly','semi_annual','annual','custom')",
      name: "maintenance_schedules_frequency_check"
    remove_column :maintenance_schedules, :interval_unit
    remove_column :maintenance_schedules, :interval_value
    remove_reference :maintenance_schedules, :room, foreign_key: true

    remove_foreign_key :documents, column: :maintenance_request_id if
      foreign_key_exists?(:documents, :maintenance_requests, column: :maintenance_request_id)
    remove_check_constraint :documents, name: "documents_must_have_parent"
    add_check_constraint :documents,
      "property_id IS NOT NULL OR lease_id IS NOT NULL OR inspection_id IS NOT NULL OR " \
      "maintenance_request_id IS NOT NULL OR damage_assessment_id IS NOT NULL OR property_ownership_id IS NOT NULL",
      name: "documents_must_have_parent"
    remove_reference :documents, :maintenance_financial_entry, foreign_key: true

    remove_index :maintenance_financial_entries, name: "idx_maintenance_invoice_reference"
    remove_index :maintenance_financial_entries, name: "idx_maintenance_entries_one_selected_quote"
    remove_check_constraint :maintenance_financial_entries, name: "maintenance_financial_entries_status_check"
    remove_check_constraint :maintenance_financial_entries, name: "maintenance_financial_entries_payment_invoice_check"
    remove_check_constraint :maintenance_financial_entries, name: "maintenance_financial_entries_sti_entry_type_check"
    remove_check_constraint :maintenance_financial_entries, name: "maintenance_financial_entries_sti_type_check"
    remove_reference :maintenance_financial_entries, :invoice, foreign_key: { to_table: :maintenance_financial_entries }
    remove_reference :maintenance_financial_entries, :decision_by, foreign_key: { to_table: :users }
    remove_column :maintenance_financial_entries, :decision_reason
    remove_column :maintenance_financial_entries, :decision_at
    remove_column :maintenance_financial_entries, :invoice_reference
    remove_column :maintenance_financial_entries, :due_on
    remove_column :maintenance_financial_entries, :valid_until
    remove_column :maintenance_financial_entries, :status
    remove_column :maintenance_financial_entries, :type

    remove_check_constraint :maintenance_cost_allocations, name: "maintenance_cost_allocations_percentage_check"
    remove_check_constraint :maintenance_cost_allocations, name: "maintenance_cost_allocations_party_check"
    add_check_constraint :maintenance_cost_allocations,
      "responsible_party IN ('owner','tenant','shared','other')",
      name: "maintenance_cost_allocations_party_check"
    remove_reference :maintenance_cost_allocations, :property_ownership, foreign_key: true
    remove_reference :maintenance_cost_allocations, :lease, foreign_key: true
    remove_column :maintenance_cost_allocations, :approved_at
    remove_column :maintenance_cost_allocations, :allocation_percentage

    remove_check_constraint :maintenance_requests, name: "maintenance_requests_suggested_responsibility_check"
    remove_reference :maintenance_requests, :verified_by, foreign_key: { to_table: :users }
    remove_reference :maintenance_requests, :rejected_by, foreign_key: { to_table: :users }
    remove_column :maintenance_requests, :verified_at
    remove_column :maintenance_requests, :rejected_at
    remove_column :maintenance_requests, :suggested_responsibility
  end

  private

  def abort_if_orphaned_maintenance_documents
    orphan_count = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM documents
      LEFT JOIN maintenance_requests
        ON maintenance_requests.id = documents.maintenance_request_id
      WHERE documents.maintenance_request_id IS NOT NULL
        AND maintenance_requests.id IS NULL
    SQL
    return if orphan_count.zero?

    raise ActiveRecord::MigrationError,
      "#{orphan_count} documents reference missing maintenance requests; resolve the orphaned records before retrying."
  end

  def abort_if_invalid_custom_schedules
    invalid_count = select_value(<<~SQL).to_i
      SELECT COUNT(*)
      FROM maintenance_schedules
      WHERE frequency = 'custom'
        AND interval_months IS NULL
    SQL
    return if invalid_count.zero?

    raise ActiveRecord::MigrationError,
      "#{invalid_count} custom schedules lack an interval; resolve them before retrying."
  end

  def abort_if_phase2_domain_data_exists
    checks = {
      maintenance_requests: "suggested_responsibility <> 'unknown' OR rejected_at IS NOT NULL OR " \
        "rejected_by_id IS NOT NULL OR verified_at IS NOT NULL OR verified_by_id IS NOT NULL",
      maintenance_cost_allocations: "allocation_percentage IS NOT NULL OR approved_at IS NOT NULL OR " \
        "lease_id IS NOT NULL OR property_ownership_id IS NOT NULL OR " \
        "responsible_party IN ('organization','third_party')",
      maintenance_financial_entries: "type IS NOT NULL OR status <> 'recorded' OR valid_until IS NOT NULL OR " \
        "due_on IS NOT NULL OR invoice_reference IS NOT NULL OR decision_at IS NOT NULL OR " \
        "decision_reason IS NOT NULL OR decision_by_id IS NOT NULL OR invoice_id IS NOT NULL",
      documents: "maintenance_financial_entry_id IS NOT NULL",
      maintenance_schedules: "room_id IS NOT NULL OR interval_value IS NOT NULL OR interval_unit IS NOT NULL OR " \
        "frequency IN ('daily','weekly') OR " \
        "suggested_responsibility IN ('organization','third_party','unknown')"
    }

    checks.each do |table, condition|
      count = select_value("SELECT COUNT(*) FROM #{quote_table_name(table)} WHERE #{condition}").to_i
      next if count.zero?

      raise ActiveRecord::MigrationError,
        "Cannot roll back maintenance domain details because #{table} contains #{count} Phase 2 records."
    end
  end
end
