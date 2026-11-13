export type MaintenanceUnit = {
  id: string
  unit_number?: string
  name?: string
}

export type MaintenanceRoom = {
  id: string
  unit_id: string
  room_name: string
}

export type MaintenanceItem = {
  id: string
  name: string
  room_id?: string | null
  unit_id?: string | null
}

export type MaintenanceLease = {
  id: string
  unit_id: string
  tenant_id: string
  tenant_name: string
  status: string
  start_date: string
  end_date?: string | null
}

export type MaintenanceAssignment = {
  id: string
  user: { id: string; name: string; email: string }
  assignment_type: string
  starts_at: string
  ends_at?: string | null
}

export type MaintenanceInspection = {
  id: string
  inspection_type: string
  status: string
  scheduled_on?: string
  inspected_on?: string
}

export type MaintenanceDamageAssessment = {
  id: string
  description: string
  severity: string
  assessed_on: string
}

export type MaintenancePortfolioContext = {
  units: MaintenanceUnit[]
  rooms: MaintenanceRoom[]
  items: MaintenanceItem[]
  leases: MaintenanceLease[]
  assignments: MaintenanceAssignment[]
  inspections: MaintenanceInspection[]
  damage_assessments: MaintenanceDamageAssessment[]
  parties?: MaintenanceParty[]
  maintenance?: Array<{ currency?: string | null }>
}

export type MaintenanceParty = { id: string; name: string; party_type: string }

export type MaintenanceAllocation = {
  id: string
  responsible_party: string
  status: 'approved' | 'superseded'
  party_id?: string | null
  allocated_amount: number | string
  allocation_percentage?: number | string | null
  currency: string
  rationale: string
  lease_id?: string | null
  property_ownership_id?: string | null
  approved_by_id: string
  approved_at?: string | null
}

export type MaintenanceFinancialEntry = {
  id: string
  entry_type: 'quotation' | 'invoice' | 'payment'
  amount: number | string
  currency: string
  status: string
  occurred_on: string
  reference?: string | null
  notes?: string | null
  valid_until?: string | null
  due_on?: string | null
  invoice_reference?: string | null
  invoice_id?: string | null
  decision_by_id?: string | null
  decision_at?: string | null
  decision_reason?: string | null
  party_id?: string | null
  recorded_by_id?: string | null
}

export type MaintenanceDocument = {
  id: string
  title: string
  document_type: string
  description?: string | null
  content_type?: string | null
  file_size_bytes?: number | null
  url?: string | null
  uploaded_by_id?: string | null
  created_at: string
}

export type MaintenanceAuditEvent = {
  action: string
  actor_id?: string | null
  changes: Record<string, unknown>
  occurred_at: string
}

export type MaintenanceRequest = {
  id: string
  property_id: string
  unit_id?: string | null
  room_id?: string | null
  title: string
  description?: string | null
  category?: string | null
  priority: string
  status: string
  classification: string
  suggested_responsibility: string
  responsibility_status: string
  responsibility_notes?: string | null
  responsibility_reviewed_by_id?: string | null
  responsibility_reviewed_at?: string | null
  approval_notes?: string | null
  rejection_reason?: string | null
  cancellation_reason?: string | null
  source_type: string
  source_inspection_id?: string | null
  source_inspection_item_id?: string | null
  source_damage_assessment_id?: string | null
  maintenance_schedule_id?: string | null
  lease_id?: string | null
  contractor_id?: string | null
  reported_by_id?: string | null
  assigned_to_id?: string | null
  reported_at: string
  acknowledged_at?: string | null
  scheduled_on?: string | null
  target_completion_on?: string | null
  actual_started_at?: string | null
  resolved_at?: string | null
  closed_at?: string | null
  estimated_cost?: number | string | null
  approved_cost?: number | string | null
  actual_cost?: number | string | null
  currency: string
  approved_by_id?: string | null
  approved_at?: string | null
  rejected_by_id?: string | null
  rejected_at?: string | null
  verified_by_id?: string | null
  verified_at?: string | null
  closed_by_id?: string | null
  resolution_notes?: string | null
  cost_allocations: MaintenanceAllocation[]
  financial_entries: MaintenanceFinancialEntry[]
  documents: MaintenanceDocument[]
  audit_history: MaintenanceAuditEvent[]
  created_at: string
  updated_at: string
}

export type MaintenanceSchedule = {
  id: string
  property_id: string
  unit_id?: string | null
  room_id?: string | null
  title: string
  description?: string | null
  category?: string | null
  priority: string
  classification: string
  suggested_responsibility: string
  frequency: string
  interval_months?: number | null
  interval_value?: number | null
  interval_unit?: string | null
  starts_on: string
  ends_on?: string | null
  next_due_on: string
  target_completion_on?: string | null
  reminder_days?: number | null
  status: string
  generation_mode: string
  estimated_cost?: number | string | null
  currency: string
  assigned_to_id?: string | null
  contractor_id?: string | null
}

export type MaintenanceView =
  | 'overview'
  | 'work_orders'
  | 'upcoming'
  | 'in_progress'
  | 'completed'
  | 'history'
  | 'costs'
  | 'calendar'
  | 'schedules'
