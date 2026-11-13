module MaintenanceSerialization
  private

  def maintenance_request_payload(request, audit_logs: nil, blobs_by_key: nil)
    {
      id: request.id,
      property_id: request.property_id,
      unit_id: request.unit_id,
      room_id: request.room_id,
      title: request.title,
      description: request.description,
      category: request.category,
      priority: request.priority,
      status: request.status,
      classification: request.classification,
      suggested_responsibility: request.suggested_responsibility,
      responsibility_status: request.responsibility_status,
      responsibility_notes: request.responsibility_notes,
      responsibility_reviewed_by_id: request.responsibility_reviewed_by_id,
      responsibility_reviewed_at: request.responsibility_reviewed_at,
      approval_notes: request.approval_notes,
      rejection_reason: request.rejection_reason,
      cancellation_reason: request.cancellation_reason,
      source_type: request.source_type,
      source_inspection_id: request.source_inspection_id,
      source_inspection_item_id: request.source_inspection_item_id,
      source_damage_assessment_id: request.source_damage_assessment_id,
      maintenance_schedule_id: request.maintenance_schedule_id,
      lease_id: request.lease_id,
      contractor_id: request.contractor_id,
      reported_by_id: request.reported_by_id,
      assigned_to_id: request.assigned_to_id,
      reported_at: request.reported_at,
      acknowledged_at: request.acknowledged_at,
      scheduled_on: request.scheduled_on,
      target_completion_on: request.target_completion_on,
      actual_started_at: request.actual_started_at,
      resolved_at: request.resolved_at,
      closed_at: request.closed_at,
      estimated_cost: request.estimated_cost,
      approved_cost: request.approved_cost,
      actual_cost: request.actual_cost,
      currency: request.currency,
      approved_by_id: request.approved_by_id,
      approved_at: request.approved_at,
      rejected_by_id: request.rejected_by_id,
      rejected_at: request.rejected_at,
      verified_by_id: request.verified_by_id,
      verified_at: request.verified_at,
      closed_by_id: request.closed_by_id,
      resolution_notes: request.resolution_notes,
      cost_allocations: request.cost_allocations.map { |allocation| cost_allocation_payload(allocation) },
      financial_entries: request.financial_entries.sort_by { |entry| [entry.occurred_on, entry.created_at] }
        .map { |entry| financial_entry_payload(entry) },
      documents: request.documents.sort_by { |document| [document.created_at, document.id] }.map do |document|
        document_payload(document, blob: blobs_by_key&.[](document.storage_key))
      end,
      audit_history: (audit_logs || AuditLog.for_record(request).where(organization_id: request.organization_id).order(:occurred_at)).map do |log|
        {
          action: log.action,
          actor_id: log.actor_id,
          changes: log.changes_payload,
          occurred_at: log.occurred_at
        }
      end,
      created_at: request.created_at,
      updated_at: request.updated_at
    }
  end

  def maintenance_schedule_payload(schedule)
    {
      id: schedule.id,
      property_id: schedule.property_id,
      unit_id: schedule.unit_id,
      title: schedule.title,
      description: schedule.description,
      category: schedule.category,
      priority: schedule.priority,
      classification: schedule.classification,
      suggested_responsibility: schedule.suggested_responsibility,
      frequency: schedule.frequency,
      interval_months: schedule.interval_months,
      interval_value: schedule.interval_value,
      interval_unit: schedule.interval_unit,
      starts_on: schedule.starts_on,
      ends_on: schedule.ends_on,
      next_due_on: schedule.next_due_on,
      target_completion_on: schedule.target_completion_on,
      room_id: schedule.room_id,
      reminder_days: schedule.reminder_days,
      status: schedule.status,
      generation_mode: schedule.generation_mode,
      estimated_cost: schedule.estimated_cost,
      currency: schedule.currency,
      assigned_to_id: schedule.assigned_to_id,
      contractor_id: schedule.contractor_id
    }
  end

  def cost_allocation_payload(allocation)
    {
      id: allocation.id,
      responsible_party: allocation.responsible_party,
      status: allocation.status,
      party_id: allocation.party_id,
      allocated_amount: allocation.allocated_amount,
      currency: allocation.currency,
      rationale: allocation.rationale,
      allocation_percentage: allocation.allocation_percentage,
      lease_id: allocation.lease_id,
      property_ownership_id: allocation.property_ownership_id,
      approved_by_id: allocation.approved_by_id,
      approved_at: allocation.approved_at,
      created_at: allocation.created_at
    }
  end

  def financial_entry_payload(entry)
    {
      id: entry.id,
      entry_type: entry.entry_type,
      amount: entry.amount,
      currency: entry.currency,
      status: entry.status,
      occurred_on: entry.occurred_on,
      reference: entry.reference,
      notes: entry.notes,
      valid_until: entry.valid_until,
      due_on: entry.due_on,
      invoice_reference: entry.invoice_reference,
      invoice_id: entry.invoice_id,
      decision_by_id: entry.decision_by_id,
      decision_at: entry.decision_at,
      decision_reason: entry.decision_reason,
      party_id: entry.party_id,
      recorded_by_id: entry.recorded_by_id
    }
  end
end
