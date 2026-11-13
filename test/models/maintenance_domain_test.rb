require "test_helper"

class MaintenanceDomainTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Maintenance domain #{SecureRandom.hex(4)}")
    @manager = create_user(@organization, "manager")
    @property = @organization.properties.create!(name: "Domain property", property_type: "residential")
  end

  test "classification and suggested responsibility do not create a financial decision" do
    request = create_request(classification: "negligence")

    assert_equal "unknown", request.suggested_responsibility
    assert_equal "pending_review", request.responsibility_status
    assert_empty request.cost_allocations
  end

  test "approved allocations reconcile amounts and optional percentages" do
    request = create_request(approved_cost: 100)
    create_allocation(request, amount: 65, percentage: 65)
    create_allocation(request, amount: 35, percentage: 35)

    request.update!(
      responsibility_status: "approved",
      responsibility_reviewed_by: @manager,
      responsibility_reviewed_at: Time.current
    )

    assert_equal "approved", request.reload.responsibility_status
  end

  test "responsibility cannot be approved with unreconciled amounts" do
    request = create_request(approved_cost: 100)
    create_allocation(request, amount: 99, percentage: 100)

    assert_not request.update(responsibility_status: "approved")
    assert request.errors[:cost_allocations].any?
  end

  test "responsibility cannot be approved without reviewed allocations" do
    request = create_request(approved_cost: 100)

    assert_not request.update(responsibility_status: "approved")
    assert request.errors[:cost_allocations].any?
  end

  test "preserves the original maintenance request statuses" do
    %w[open acknowledged in_progress resolved closed].each do |status|
      request = create_request(status: status)
      assert request.valid?, "#{status} should remain valid"
    end

    cancelled = create_request(status: "cancelled", cancellation_reason: "No longer required")
    assert cancelled.valid?
  end

  test "allocation percentages are bounded" do
    allocation = MaintenanceCostAllocation.new(
      organization: @organization,
      maintenance_request: create_request(approved_cost: 100),
      responsible_party: "organization",
      allocated_amount: 100,
      allocation_percentage: 100.01,
      currency: "ZAR",
      rationale: "Reviewed allocation",
      approved_by: @manager
    )

    assert_not allocation.valid?
    assert allocation.errors[:allocation_percentage].any?
  end

  test "quotes and invoices retain distinct types and allow multiple records" do
    request = create_request
    insurer = @organization.parties.create!(name: "Insurer", party_type: "insurer")
    first_quote = create_quote(request, amount: 120, reference: "Q-1")
    second_quote = create_quote(request, amount: 135, reference: "Q-2")
    first_invoice = create_invoice(request, amount: 100, reference: "I-1", party: insurer)
    second_invoice = create_invoice(request, amount: 50, reference: "I-2")

    assert_instance_of MaintenanceQuote, request.financial_entries.find(first_quote.id)
    assert_instance_of MaintenanceQuote, request.financial_entries.find(second_quote.id)
    assert_instance_of MaintenanceInvoice, request.financial_entries.find(first_invoice.id)
    assert_equal 2, request.invoices.count
    assert_equal "I-2", second_invoice.invoice_reference
    assert_equal insurer, first_invoice.party
  end

  test "only one quotation may be selected and decisions retain reviewer metadata" do
    request = create_request
    selected = create_quote(request, amount: 120, reference: "Q-1")
    other = create_quote(request, amount: 135, reference: "Q-2")

    selected.update!(status: "selected", decision_by: @manager, decision_at: Time.current)
    other.assign_attributes(status: "selected", decision_by: @manager, decision_at: Time.current)

    assert_not other.valid?
    assert other.errors[:status].any?
    assert_equal @manager, selected.reload.decision_by
  end

  test "partial payments calculate balances and reject overpayment" do
    request = create_request
    invoice = create_invoice(request, amount: 100, reference: "I-1")
    payment = create_payment(invoice, amount: 60, status: "paid")

    assert_equal BigDecimal("60"), invoice.paid_amount
    assert_equal BigDecimal("40"), invoice.outstanding_balance
    assert_equal "partially_paid", invoice.payment_state

    overpayment = build_payment(invoice, amount: 50, status: "paid")
    assert_not overpayment.valid?
    assert overpayment.errors[:amount].any?
    assert_equal payment, invoice.payments.sole
  end

  test "financial records and evidence enforce organisation and currency consistency" do
    request = create_request
    invoice = create_invoice(request, amount: 100, reference: "I-1")
    document = Document.new(
      organization: @organization,
      uploaded_by: @manager,
      maintenance_financial_entry: invoice,
      document_type: "invoice",
      title: "Invoice",
      storage_key: "invoice-test-key"
    )
    assert document.valid?, document.errors.full_messages.inspect

    other_organization = Organization.create!(name: "Other maintenance org #{SecureRandom.hex(4)}")
    other_user = create_user(other_organization, "other")
    cross_tenant_document = Document.new(
      organization: other_organization,
      uploaded_by: other_user,
      maintenance_financial_entry: invoice,
      document_type: "invoice",
      title: "Foreign invoice",
      storage_key: "foreign-invoice-test-key"
    )
    assert_not cross_tenant_document.valid?
    assert cross_tenant_document.errors[:maintenance_request].any?

    other_property = @organization.properties.create!(name: "Foreign evidence property", property_type: "residential")
    cross_property_document = Document.new(
      organization: @organization,
      uploaded_by: @manager,
      property: other_property,
      maintenance_financial_entry: invoice,
      document_type: "invoice",
      title: "Misfiled invoice",
      storage_key: "misfiled-invoice-test-key"
    )
    assert_not cross_property_document.valid?
    assert cross_property_document.errors[:maintenance_request].any?

    wrong_currency_payment = build_payment(invoice, amount: 10, currency: "USD")
    assert_not wrong_currency_payment.valid?
    assert wrong_currency_payment.errors[:currency].any?
  end

  test "schedule supports daily, weekly and custom day intervals with room validation" do
    building = @organization.buildings.create!(property: @property, name: "Main")
    unit = @organization.units.create!(property: @property, building: building, bedrooms: 1, bathrooms: 1)
    room = @organization.rooms.create!(
      property: @property,
      building: building,
      unit: unit,
      room_name: "Kitchen",
      room_type: "kitchen"
    )
    due_on = Date.current

    daily = create_schedule(frequency: "daily", room: room, unit: unit, due_on: due_on)
    weekly = create_schedule(frequency: "weekly", due_on: due_on)
    custom = create_schedule(
      frequency: "custom",
      interval_value: 2,
      interval_unit: "week",
      due_on: due_on
    )

    assert_equal due_on + 1, daily.next_due_date(due_on)
    assert_equal due_on + 7, weekly.next_due_date(due_on)
    assert_equal due_on + 14, custom.next_due_date(due_on)

    other_property = @organization.properties.create!(name: "Other property", property_type: "residential")
    other_building = @organization.buildings.create!(property: other_property, name: "Other")
    other_unit = @organization.units.create!(
      property: other_property,
      building: other_building,
      bedrooms: 1,
      bathrooms: 1
    )
    foreign_room = @organization.rooms.create!(
      property: other_property,
      building: other_building,
      unit: other_unit,
      room_name: "Bedroom",
      room_type: "bedroom"
    )
    invalid_schedule = MaintenanceSchedule.new(
      organization: @organization,
      property: @property,
      room: foreign_room,
      created_by: @manager,
      title: "Invalid room plan",
      starts_on: due_on,
      next_due_on: due_on,
      frequency: "once"
    )
    assert_not invalid_schedule.valid?
    assert invalid_schedule.errors[:room].any?
  end

  private

  def create_user(organization, prefix)
    organization.users.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "password123"
    )
  end

  def create_request(attributes = {})
    MaintenanceRequest.create!(
      {
        organization: @organization,
        property: @property,
        reported_by: @manager,
        title: "Maintenance request",
        priority: "medium",
        status: "open",
        reported_at: Time.current
      }.merge(attributes)
    )
  end

  def create_quote(request, amount:, reference:)
    MaintenanceQuote.create!(
      organization: @organization,
      maintenance_request: request,
      recorded_by: @manager,
      amount: amount,
      currency: request.currency,
      occurred_on: Date.current,
      reference: reference
    )
  end

  def create_invoice(request, amount:, reference:, party: nil)
    MaintenanceInvoice.create!(
      organization: @organization,
      maintenance_request: request,
      party: party,
      recorded_by: @manager,
      amount: amount,
      currency: request.currency,
      occurred_on: Date.current,
      invoice_reference: reference
    )
  end

  def build_payment(invoice, amount:, status:, currency: invoice.currency)
    MaintenancePayment.new(
      organization: @organization,
      maintenance_request: invoice.maintenance_request,
      invoice: invoice,
      recorded_by: @manager,
      amount: amount,
      currency: currency,
      occurred_on: Date.current,
      status: status
    )
  end

  def create_payment(invoice, amount:, status:)
    build_payment(invoice, amount: amount, status: status).tap(&:save!)
  end

  def create_allocation(request, amount:, percentage:)
    request.cost_allocations.create!(
      organization: @organization,
      responsible_party: "owner",
      allocated_amount: amount,
      allocation_percentage: percentage,
      currency: request.currency,
      rationale: "Reviewed allocation",
      approved_by: @manager
    )
  end

  def create_schedule(frequency:, due_on:, **attributes)
    @property.maintenance_schedules.create!(
      {
        organization: @organization,
        created_by: @manager,
        title: "Scheduled maintenance",
        starts_on: due_on,
        next_due_on: due_on,
        frequency: frequency
      }.merge(attributes)
    )
  end
end
