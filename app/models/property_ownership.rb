class PropertyOwnership < ApplicationRecord
  include TenantScoped
  include Auditable

  VERIFICATION_STATUSES = %w[unverified pending_review verified].freeze

  belongs_to :property
  belongs_to :party
  belongs_to :verified_by, class_name: "User", optional: true
  has_many :documents, inverse_of: :property_ownership
  has_many :maintenance_cost_allocations

  scope :chronological, -> { order(:start_date, :created_at, :id) }
  scope :active_on, ->(date = Date.current) {
    where("start_date <= ? AND (end_date IS NULL OR end_date > ?)", date, date)
  }

  before_validation :normalize_currency

  validates :start_date, :ownership_percentage, presence: true
  validates :ownership_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }
  validates :currency, format: { with: /\A[A-Z]{3}\z/, message: "must be a three-letter currency code" }, allow_nil: true
  validates :transfer_value, :valuation_at_transfer, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :end_date_is_not_before_start_date
  validate :financial_values_have_currency
  validate :verification_metadata_is_consistent
  validate :associations_belong_to_organization
  validate :ownership_percentages_do_not_exceed_100

  def effective_status(date = Date.current)
    return "upcoming" if start_date && start_date > date
    return "historical" if end_date && end_date <= date

    "current"
  end

  private

  def normalize_currency
    self.currency = currency.strip.upcase.presence if currency.is_a?(String)
  end

  def end_date_is_not_before_start_date
    return if start_date.blank? || end_date.blank? || end_date >= start_date

    errors.add(:end_date, "cannot be before the acquisition date")
  end

  def financial_values_have_currency
    amount_changed = new_record? || will_save_change_to_transfer_value? ||
      will_save_change_to_valuation_at_transfer? || will_save_change_to_currency?
    return unless amount_changed && (transfer_value.present? || valuation_at_transfer.present?) && currency.blank?

    errors.add(:currency, "is required when a transaction amount or valuation is recorded")
  end

  def verification_metadata_is_consistent
    if verification_status == "verified" && (verified_at.blank? || verified_by.blank?)
      errors.add(:verification_status, "requires a verifier and verification date")
    elsif verification_status != "verified" && (verified_at.present? || verified_by.present?)
      errors.add(:verification_status, "cannot have verifier details unless verified")
    end
  end

  def associations_belong_to_organization
    errors.add(:property, "must belong to the same organization") if property && property.organization_id != organization_id
    errors.add(:party, "must belong to the same organization") if party && party.organization_id != organization_id

    if verified_by && verified_by.organization_id != organization_id
      errors.add(:verified_by, "must belong to the same organization")
    end
  end

  def ownership_percentages_do_not_exceed_100
    return if property_id.blank? || organization_id.blank? || start_date.blank? ||
      ownership_percentage.blank? || (end_date.present? && end_date <= start_date)

    existing = property.property_ownerships
      .where(organization_id: organization_id)
      .where.not(id: id)
    existing = existing.where("end_date IS NULL OR end_date > ?", start_date)
    existing = existing.where("start_date < ?", end_date) if end_date.present?
    boundaries = [start_date] + existing.pluck(:start_date).select do |date|
      date >= start_date && (end_date.nil? || date < end_date)
    end

    boundaries.uniq.each do |date|
      active_total = existing
        .where("start_date <= ? AND (end_date IS NULL OR end_date > ?)", date, date)
        .sum(:ownership_percentage)
      next unless active_total + ownership_percentage.to_d > 100

      errors.add(:ownership_percentage, "would make combined ownership exceed 100% on #{date}")
      break
    end
  end
end