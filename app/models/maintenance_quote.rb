class MaintenanceQuote < MaintenanceFinancialEntry
  STATUSES = %w[draft received selected rejected expired superseded].freeze

  alias_attribute :quoted_on, :occurred_on
  alias_attribute :quoted_amount, :amount

  before_validation :set_quote_defaults

  validates :status, inclusion: { in: STATUSES }
  validate :validity_date_follows_quote_date
  validate :decision_metadata_is_present
  validate :only_one_selected_quote

  private

  def set_quote_defaults
    self.entry_type = "quotation"
    self.status = "received" if status == "recorded"
  end

  def validity_date_follows_quote_date
    return if valid_until.blank? || occurred_on.blank? || valid_until >= occurred_on

    errors.add(:valid_until, "cannot be before the quotation date")
  end

  def decision_metadata_is_present
    return unless %w[selected rejected].include?(status)

    errors.add(:decision_by, "is required for a quote decision") if decision_by.blank?
    errors.add(:decision_at, "is required for a quote decision") if decision_at.blank?
    if status == "rejected" && decision_reason.blank?
      errors.add(:decision_reason, "is required when rejecting a quote")
    end
  end

  def only_one_selected_quote
    return unless status == "selected" && maintenance_request
    return unless maintenance_request.quotes.where(status: "selected").where.not(id: id).exists?

    errors.add(:status, "cannot select more than one quotation for a work order")
  end
end
