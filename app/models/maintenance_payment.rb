class MaintenancePayment < MaintenanceFinancialEntry
  STATUSES = %w[pending paid failed cancelled].freeze
  RESERVED_STATUSES = %w[pending paid].freeze

  alias_attribute :payment_date, :occurred_on

  before_validation :set_payment_defaults
  validates :status, inclusion: { in: STATUSES }
  validate :payment_does_not_exceed_invoice_balance

  private

  def set_payment_defaults
    self.entry_type = "payment"
    self.status = "pending" if status == "recorded"
  end

  def payment_does_not_exceed_invoice_balance
    unless invoice.is_a?(MaintenanceInvoice) && invoice.persisted?
      errors.add(:invoice, "must be a maintenance invoice")
      return
    end
    return unless RESERVED_STATUSES.include?(status)

    return unless amount && currency == invoice.currency

    reserved_by_other_payments = invoice.payments
      .where(status: RESERVED_STATUSES)
      .where.not(id: id)
      .sum(:amount)
    if reserved_by_other_payments + amount > invoice.amount
      errors.add(:amount, "would exceed the invoice balance")
    end
  end

end
