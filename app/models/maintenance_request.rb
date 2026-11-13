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
  belongs_to :closed_by, class_name: "User", optional: true
  has_many :documents, foreign_key: :maintenance_request_id
  has_many :cost_allocations, class_name: "MaintenanceCostAllocation", dependent: :restrict_with_error
  has_many :financial_entries, class_name: "MaintenanceFinancialEntry", dependent: :restrict_with_error

  PRIORITIES = %w[low medium high urgent].freeze
  STATUSES = %w[open acknowledged awaiting_approval approved scheduled in_progress resolved closed rejected disputed cancelled].freeze
  CLASSIFICATIONS = %w[
    wear_and_tear accidental_damage negligence misuse structural_deterioration
    preventative_maintenance breakdown improvement compliance_safety other undetermined
  ].freeze
  RESPONSIBILITY_STATUSES = %w[pending_review approved disputed].freeze
  SOURCE_TYPES = %w[tenant_request schedule inspection damage_assessment manager other].freeze

  validates :title,       presence: true
  validates :priority,    inclusion: { in: PRIORITIES }
  validates :status,      inclusion: { in: STATUSES }
  validates :reported_at, presence: true
  validates :classification, inclusion: { in: CLASSIFICATIONS }
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

    [reported_by, assigned_to, approved_by, responsibility_reviewed_by, closed_by].compact.each do |user|
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

  def target_completion_is_not_before_schedule
    return if scheduled_on.blank? || target_completion_on.blank? || target_completion_on >= scheduled_on

    errors.add(:target_completion_on, "cannot be before the scheduled date")
  end
end
