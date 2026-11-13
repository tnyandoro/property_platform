class MaintenanceFinancialEntryRecorder
  class InvalidEntry < StandardError; end

  ENTRY_CLASSES = {
    "quotation" => MaintenanceQuote,
    "invoice" => MaintenanceInvoice,
    "payment" => MaintenancePayment
  }.freeze

  def self.call(request:, actor:, attributes:)
    new(request, actor, attributes).call
  end

  def self.call_legacy(request:, actor:, attributes:)
    new(request, actor, attributes).call_legacy
  end

  def initialize(request, actor, attributes)
    @request = request
    @actor = actor
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
    entry_class = ENTRY_CLASSES[attributes[:entry_type]]
    raise InvalidEntry, "Choose a valid financial entry type." unless entry_class

    party = request.organization.parties.find(attributes[:party_id]) if attributes[:party_id].present?
    entry = entry_class.new(
      common_attributes.merge(
        organization: request.organization,
        maintenance_request: request,
        recorded_by: actor,
        party: party
      )
    )
    assign_subtype_attributes(entry)
    unless entry.is_a?(MaintenancePayment)
      entry.save!
      return entry
    end

    invoice = request.invoices.find(attributes[:invoice_id]) if attributes[:invoice_id].present?
    raise InvalidEntry, "A payment must reference an invoice belonging to this work order." unless invoice

    invoice.with_lock do
      entry.invoice = invoice
      entry.save!
    end
    entry
  end

  def call_legacy
    entry = MaintenanceFinancialEntry.new(
      common_attributes.merge(
        organization: request.organization,
        maintenance_request: request,
        recorded_by: actor,
        party: party
      )
    )
    entry.save!
    entry
  end

  private

  attr_reader :request, :actor, :attributes

  def common_attributes
    attributes.slice(:entry_type, :amount, :currency, :occurred_on, :reference, :notes)
      .merge(currency: attributes[:currency].presence || request.currency)
  end

  def party
    request.organization.parties.find(attributes[:party_id]) if attributes[:party_id].present?
  end

  def assign_subtype_attributes(entry)
    case entry
    when MaintenanceQuote
      entry.valid_until = attributes[:valid_until]
    when MaintenanceInvoice
      entry.invoice_reference = attributes[:invoice_reference]
      entry.due_on = attributes[:due_on]
    when MaintenancePayment
      entry.status = attributes[:status] if attributes[:status].present?
    end
  end
end
