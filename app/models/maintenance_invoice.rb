class MaintenanceInvoice < MaintenanceFinancialEntry
  STATUSES = %w[received approved overdue disputed cancelled].freeze

  alias_attribute :invoice_date, :occurred_on
  has_many :payments,
    class_name: "MaintenancePayment",
    foreign_key: :invoice_id,
    inverse_of: :invoice,
    dependent: :restrict_with_error

  before_validation :set_invoice_defaults

  validates :status, inclusion: { in: STATUSES }
  validates :invoice_reference, presence: true, uniqueness: { scope: [:organization_id, :party_id] }
  validate :due_date_follows_invoice_date
  validate :amount_covers_existing_payments, if: :will_save_change_to_amount?

  def paid_amount
    payments.where(status: "paid").sum(:amount)
  end

  def outstanding_balance
    amount - paid_amount
  end

  def payment_state
    return "paid" if outstanding_balance.zero?
    return "overdue" if due_on.present? && due_on < Date.current
    return "partially_paid" if paid_amount.positive?

    "unpaid"
  end

  private

  def set_invoice_defaults
    self.entry_type = "invoice"
    self.status = "received" if status == "recorded"
    self.invoice_reference = reference if invoice_reference.blank? && reference.present?
    self.reference = invoice_reference if invoice_reference.present?
  end

  def due_date_follows_invoice_date
    return if due_on.blank? || occurred_on.blank? || due_on >= occurred_on

    errors.add(:due_on, "cannot be before the invoice date")
  end

  def amount_covers_existing_payments
    return if new_record?

    reserved_amount = payments.where(status: MaintenancePayment::RESERVED_STATUSES).sum(:amount)
    return if amount && amount >= reserved_amount

    errors.add(:amount, "cannot be less than the recorded payments")
  end
end
