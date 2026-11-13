class MaintenanceRequest < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :unit,        optional: true
  belongs_to :room,        optional: true
  belongs_to :reported_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :lease, optional: true
  belongs_to :contractor, class_name: "Party", optional: true
  belongs_to :source_inspection, class_name: "Inspection", optional: true
  belongs_to :source_inspection_item, class_name: "InspectionItem", optional: true
  belongs_to :source_damage_assessment, class_name: "DamageAssessment", optional: true
  belongs_to :maintenance_schedule, optional: true
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :responsibility_reviewed_by, class_name: "User", optional: true
  belongs_to :rejected_by, class_name: "User", optional: true
  belongs_to :closed_by, class_name: "User", optional: true
  belongs_to :verified_by, class_name: "User", optional: true
  has_many :documents, foreign_key: :maintenance_request_id
  has_many :cost_allocations, class_name: "MaintenanceCostAllocation", dependent: :restrict_with_error
  has_many :financial_entries, class_name: "MaintenanceFinancialEntry", dependent: :restrict_with_error
  has_many :quotes, class_name: "MaintenanceQuote", dependent: :restrict_with_error
  has_many :invoices, class_name: "MaintenanceInvoice", dependent: :restrict_with_error
  has_many :payments, class_name: "MaintenancePayment", dependent: :restrict_with_error
  has_many :updates, class_name: "MaintenanceRequestUpdate", dependent: :restrict_with_error

  PRIORITIES = %w[low medium high urgent].freeze
  STATUSES = %w[open acknowledged awaiting_approval approved scheduled in_progress resolved closed rejected disputed cancelled].freeze
  CLASSIFICATIONS = %w[
    wear_and_tear accidental_damage negligence misuse structural_deterioration
    preventative_maintenance breakdown improvement compliance_safety other undetermined
  ].freeze
  SUGGESTED_RESPONSIBILITIES = %w[owner tenant shared organization third_party unknown].freeze
  RESPONSIBILITY_STATUSES = %w[pending_review approved disputed].freeze
  SOURCE_TYPES = %w[tenant_request schedule inspection damage_assessment manager other].freeze

  validates :title,       presence: true
  validates :priority,    inclusion: { in: PRIORITIES }
  validates :status,      inclusion: { in: STATUSES }
  validates :reported_at, presence: true
  validates :classification, inclusion: { in: CLASSIFICATIONS }
  validates :suggested_responsibility, inclusion: { in: SUGGESTED_RESPONSIBILITIES }
  validates :responsibility_status, inclusion: { in: RESPONSIBILITY_STATUSES }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :currency, presence: true
  validates :estimated_cost, :approved_cost, :actual_cost,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :source_inspection_item_id, uniqueness: true, allow_nil: true
  validates :source_damage_assessment_id, uniqueness: true, allow_nil: true
  validate :associations_match_property_and_organization
  validate :schedule_occurrence_is_present
  validate :target_completion_is_not_before_schedule
  validate :status_has_required_reason
  validate :decision_metadata_is_consistent
  validate :approved_allocations_reconcile, if: :approving_responsibility?
  validate :tenant_submission_starts_unapproved, on: :create
  before_validation :capture_verification_metadata

  scope :open,   -> { where(status: %w[open acknowledged awaiting_approval approved scheduled in_progress]) }
  scope :urgent, -> { where(priority: "urgent") }
  scope :overdue, -> {
    where("target_completion_on < ?", Date.current)
      .where.not(status: %w[resolved closed rejected cancelled])
  }

  private

  def associations_match_property_and_organization
    if property && property.organization_id != organization_id
      errors.add(:property, "must belong to the same organization")
    end
    if unit && (unit.property_id != property_id || unit.organization_id != organization_id)
      errors.add(:unit, "must belong to this property and organization")
    end
    if room && (room.property_id != property_id || room.organization_id != organization_id || (unit_id.present? && room.unit_id != unit_id))
      errors.add(:room, "must belong to this property, unit and organization")
    end

    [reported_by, assigned_to, approved_by, responsibility_reviewed_by, rejected_by, closed_by, verified_by].compact.each do |user|
      errors.add(:base, "users must belong to the same organization") if user.organization_id != organization_id
    end
    if assigned_to && property && !property.property_assignments.where(
      user_id: assigned_to_id,
      organization_id: organization_id
    ).where("starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
      .exists?
      errors.add(:assigned_to, "must have an active assignment to this property")
    end
    [lease, source_inspection, source_damage_assessment, maintenance_schedule].compact.each do |record|
      errors.add(:base, "linked records must belong to this property and organization") if record.organization_id != organization_id || record.property_id != property_id
    end
    if contractor && contractor.organization_id != organization_id
      errors.add(:contractor, "must belong to the same organization")
    end
    if source_inspection_item &&
       (source_inspection_item.organization_id != organization_id || source_inspection_item.inspection&.property_id != property_id)
      errors.add(:source_inspection_item, "must belong to this property and organization")
    end
    if source_inspection_item && source_inspection_item.inspection_id != source_inspection_id
      errors.add(:source_inspection_item, "must belong to the linked inspection")
    end
    if lease && unit_id.present? && lease.unit_id != unit_id
      errors.add(:lease, "must belong to the selected unit")
    end
  end

  def schedule_occurrence_is_present
    return if maintenance_schedule_id.blank? || occurrence_on.present?

    errors.add(:occurrence_on, "is required for a scheduled occurrence")
  end

  def status_has_required_reason
    return unless will_save_change_to_status?

    errors.add(:rejection_reason, "is required when rejecting work") if status == "rejected" && rejection_reason.blank?
    errors.add(:cancellation_reason, "is required when cancelling work") if status == "cancelled" && cancellation_reason.blank?
  end

  def decision_metadata_is_consistent
    {
      approved_by: approved_at,
      responsibility_reviewed_by: responsibility_reviewed_at,
      rejected_by: rejected_at,
      verified_by: verified_at
    }.each do |actor_attribute, timestamp|
      actor = public_send(actor_attribute)
      next if actor.blank? == timestamp.blank?

      errors.add(actor_attribute, "and its decision timestamp must be recorded together")
    end
  end

  def approving_responsibility?
    responsibility_status == "approved" && will_save_change_to_responsibility_status?
  end

  def approved_allocations_reconcile
    allocations = cost_allocations.where(status: "approved")
    if approved_cost.nil? || allocations.empty?
      errors.add(:cost_allocations, "must be recorded against an approved amount")
      return
    end

    unless allocations.sum(:allocated_amount) == approved_cost
      errors.add(:cost_allocations, "must reconcile to the approved amount")
    end

    percentages = allocations.pluck(:allocation_percentage)
    if percentages.any?(&:present?)
      if percentages.any?(&:nil?)
        errors.add(:cost_allocations, "must either all specify percentages or all omit them")
      elsif percentages.sum != 100
        errors.add(:cost_allocations, "percentages must total 100")
      end
    end
  end

  def capture_verification_metadata
    return unless will_save_change_to_status?

    actor = Current.user if Current.user&.organization_id == organization_id
    if status == "rejected"
      self.rejected_by ||= actor
      self.rejected_at ||= Time.current if rejected_by
    elsif status == "closed"
      self.verified_by ||= actor
      self.verified_at ||= Time.current if verified_by
    end
  end

  def target_completion_is_not_before_schedule
    return if scheduled_on.blank? || target_completion_on.blank? || target_completion_on >= scheduled_on

    errors.add(:target_completion_on, "cannot be before the scheduled date")
  end

  def tenant_submission_starts_unapproved
    return unless source_type == "tenant_request"

    errors.add(:status, "must be open when submitted by a tenant") unless status == "open"
    errors.add(:classification, "must remain undetermined until management review") unless classification == "undetermined"
    errors.add(:suggested_responsibility, "must remain unknown until management review") unless suggested_responsibility == "unknown"
    errors.add(:responsibility_status, "must remain pending review") unless responsibility_status == "pending_review"

    eligible_lease = lease.present? && lease.organization_id == organization_id &&
      lease.status == "active" && (lease.end_date.blank? || lease.end_date >= Date.current)
    verified_tenant_account = reported_by && lease &&
      reported_by.party_accounts.verified.joins(:tenant_profile).exists?(
        organization_id: organization_id,
        party_id: lease.tenant_id
      )
    unless eligible_lease && verified_tenant_account
      errors.add(:lease, "must be an eligible verified tenant lease")
    end

    forbidden_values = [
      estimated_cost, approved_cost, actual_cost, approved_at, approved_by,
      responsibility_reviewed_at, responsibility_reviewed_by, assigned_to,
      contractor, rejected_by, rejected_at, closed_by, verified_by, verified_at,
      scheduled_on, target_completion_on, approval_notes, responsibility_notes,
      rejection_reason, cancellation_reason
    ]
    if forbidden_values.any?(&:present?) || cost_allocations.any? || financial_entries.any?
      errors.add(:base, "tenant submissions cannot set internal, assignment, approval, or financial data")
    end
  end
end
