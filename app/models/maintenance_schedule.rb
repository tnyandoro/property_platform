class MaintenanceSchedule < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :unit, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :contractor, class_name: "Party", optional: true
  belongs_to :created_by, class_name: "User"
  has_many :maintenance_requests, dependent: :restrict_with_error

  FREQUENCIES = %w[once monthly quarterly semi_annual annual custom].freeze
  GENERATION_MODES = %w[automatic proposed reminder_only].freeze
  STATUSES = %w[active paused completed].freeze

  validates :title, :starts_on, :next_due_on, :currency, presence: true
  validates :priority, inclusion: { in: MaintenanceRequest::PRIORITIES }
  validates :classification, inclusion: { in: MaintenanceRequest::CLASSIFICATIONS }
  validates :suggested_responsibility, inclusion: { in: %w[owner tenant shared other pending] }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :generation_mode, inclusion: { in: GENERATION_MODES }
  validates :status, inclusion: { in: STATUSES }
  validates :estimated_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :interval_months, numericality: { only_integer: true, greater_than: 0 }, if: -> { frequency == "custom" }
  validate :associations_match_property_and_organization
  validate :dates_are_consistent

  scope :due, -> { where(status: "active").where("next_due_on <= ?", Date.current) }

  def due_dates_through(date)
    due_dates = []
    due_date = next_due_on
    while due_date.present? && due_date <= date && (ends_on.blank? || due_date <= ends_on)
      due_dates << due_date
      break if frequency == "once"

      due_date = next_due_date(due_date)
    end
    due_dates
  end

  def next_due_date(date)
    months = case frequency
             when "monthly" then 1
             when "quarterly" then 3
             when "semi_annual" then 6
             when "annual" then 12
             when "custom" then interval_months
             end
    months ? date.advance(months: months) : nil
  end

  private

  def associations_match_property_and_organization
    if property && property.organization_id != organization_id
      errors.add(:property, "must belong to the same organization")
    end
    if unit && (unit.property_id != property_id || unit.organization_id != organization_id)
      errors.add(:unit, "must belong to this property and organization")
    end
    [assigned_to, created_by].compact.each do |user|
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
    if contractor && contractor.organization_id != organization_id
      errors.add(:contractor, "must belong to the same organization")
    end
  end

  def dates_are_consistent
    errors.add(:ends_on, "cannot be before the start date") if ends_on.present? && starts_on.present? && ends_on < starts_on
    errors.add(:next_due_on, "cannot be before the start date") if next_due_on.present? && starts_on.present? && next_due_on < starts_on
    errors.add(:next_due_on, "cannot be after the end date") if ends_on.present? && next_due_on.present? && next_due_on > ends_on
  end
end
