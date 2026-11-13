class MaintenanceSchedule < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :unit, optional: true
  belongs_to :room, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :contractor, class_name: "Party", optional: true
  belongs_to :created_by, class_name: "User"
  has_many :maintenance_requests, dependent: :restrict_with_error

  FREQUENCIES = %w[once daily weekly monthly quarterly semi_annual annual custom].freeze
  GENERATION_MODES = %w[automatic proposed reminder_only].freeze
  STATUSES = %w[active paused completed].freeze

  validates :title, :starts_on, :next_due_on, :currency, presence: true
  validates :priority, inclusion: { in: MaintenanceRequest::PRIORITIES }
  validates :classification, inclusion: { in: MaintenanceRequest::CLASSIFICATIONS }
  validates :suggested_responsibility,
    inclusion: { in: (MaintenanceRequest::SUGGESTED_RESPONSIBILITIES + %w[other pending]).freeze }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :generation_mode, inclusion: { in: GENERATION_MODES }
  validates :status, inclusion: { in: STATUSES }
  validates :estimated_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :interval_months, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :interval_value, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
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
    case frequency
    when "daily" then date.advance(days: 1)
    when "weekly" then date.advance(weeks: 1)
    when "monthly" then advance_months(date, 1)
    when "quarterly" then advance_months(date, 3)
    when "semi_annual" then advance_months(date, 6)
    when "annual" then advance_months(date, 12)
    when "custom"
      return date.advance(days: interval_value) if interval_unit == "day" && interval_value.present?
      return date.advance(weeks: interval_value) if interval_unit == "week" && interval_value.present?
      return advance_months(date, interval_value) if interval_unit == "month" && interval_value.present?
      return advance_months(date, interval_months) if interval_months.present?
    end
  end

  private

  def advance_months(date, months)
    target_month = date.beginning_of_month.advance(months: months)
    target_month.change(day: [starts_on.day, target_month.end_of_month.day].min)
  end

  def associations_match_property_and_organization
    if property && property.organization_id != organization_id
      errors.add(:property, "must belong to the same organization")
    end
    if unit && (unit.property_id != property_id || unit.organization_id != organization_id)
      errors.add(:unit, "must belong to this property and organization")
    end
    if room && (room.property_id != property_id || room.organization_id != organization_id ||
        (unit_id.present? && room.unit_id != unit_id))
      errors.add(:room, "must belong to this property and unit")
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
    if frequency != "once" && target_completion_on.present?
      errors.add(:target_completion_on, "is only supported for one-time schedules")
    end
    if frequency == "once" && target_completion_on.present? && next_due_on.present? &&
        target_completion_on < next_due_on
      errors.add(:target_completion_on, "cannot be before the scheduled date")
    end
    return unless frequency == "custom"

    month_interval = interval_months.present?
    unit_interval = interval_value.present? && %w[day week month].include?(interval_unit)
    errors.add(:interval_value, "requires a valid interval unit or interval_months") unless month_interval || unit_interval
    if month_interval && (interval_value.present? || interval_unit.present?)
      errors.add(:interval_value, "cannot be combined with interval_months")
    end
  end
end
