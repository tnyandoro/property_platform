require "test_helper"

class MaintenanceRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Maintenance API #{SecureRandom.hex(4)}")
    @manager = @organization.users.create!(
      email: "maintenance.manager@example.com",
      first_name: "Morgan",
      last_name: "Manager",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Maintenance Property", property_type: "residential")
    @property.property_assignments.create!(
      organization: @organization,
      user: @manager,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    authenticate_as(@manager)
  end

  test "creates a property-scoped work order without implying financial responsibility" do
    assert_difference "MaintenanceRequest.count", 1 do
      post requests_path,
           params: {
             maintenance_request: {
               title: "Repair a leaking tap",
               description: "Leak is under the kitchen sink.",
               classification: "negligence",
               estimated_cost: "0",
               currency: "USD"
             }
           },
           headers: @auth_headers,
           as: :json
    end

    assert_response :created
    payload = JSON.parse(response.body)
    assert_equal "negligence", payload.fetch("classification")
    assert_equal "pending_review", payload.fetch("responsibility_status")
    assert_equal "0.0", payload.fetch("estimated_cost")
    assert payload.fetch("reported_at").present?
    assert_empty payload.fetch("cost_allocations")
  end

  test "requires a valid lifecycle transition" do
    request = create_request

    post action_path(request, "start"), headers: @auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "open", request.reload.status
  end

  test "supports the manager work-order lifecycle and its response payload" do
    request = create_request

    get requests_path, headers: @auth_headers
    assert_response :success
    assert_equal request.id, JSON.parse(response.body).sole.fetch("id")

    get "#{requests_path}/#{request.id}", headers: @auth_headers
    assert_response :success
    assert_equal request.id, JSON.parse(response.body).fetch("id")

    patch "#{requests_path}/#{request.id}",
          params: { maintenance_request: { title: "Updated work order", classification: "wear_and_tear" } },
          headers: @auth_headers,
          as: :json
    assert_response :success
    assert_equal "Updated work order", JSON.parse(response.body).fetch("title")

    post action_path(request, "acknowledge"), headers: @auth_headers, as: :json
    assert_response :success
    post action_path(request, "submit_for_approval"), headers: @auth_headers, as: :json
    assert_response :success
    post action_path(request, "approve"),
         params: { approved_cost: "300.00", comments: "Within the approved maintenance budget." },
         headers: @auth_headers,
         as: :json
    assert_response :success
    post action_path(request, "schedule"),
         params: { scheduled_on: Date.current.to_s, target_completion_on: Date.current.to_s },
         headers: @auth_headers,
         as: :json
    assert_response :success
    post action_path(request, "start"), headers: @auth_headers, as: :json
    assert_response :success
    post action_path(request, "complete"),
         params: { actual_cost: "275.50", resolution_notes: "Repair completed." },
         headers: @auth_headers,
         as: :json
    assert_response :success
    post action_path(request, "verify"), headers: @auth_headers, as: :json
    assert_response :success
    post action_path(request, "close"), headers: @auth_headers, as: :json
    assert_response :success

    request.reload
    assert_equal "closed", request.status
    assert_equal BigDecimal("275.50"), request.actual_cost
    assert_equal @manager.id, request.verified_by_id
    assert_equal @manager.id, request.closed_by_id
  end

  test "rejects approval, cancellation and responsibility changes without required inputs" do
    awaiting = create_request(status: "awaiting_approval")
    post action_path(awaiting, "reject"),
         params: { reason: "Estimate exceeds scope." },
         headers: @auth_headers,
         as: :json
    assert_response :success
    assert_equal "rejected", awaiting.reload.status
    assert_equal @manager.id, awaiting.rejected_by_id

    cancellable = create_request
    post action_path(cancellable, "cancel"),
         params: { reason: "Owner postponed the repair." },
         headers: @auth_headers,
         as: :json
    assert_response :success
    assert_equal "cancelled", cancellable.reload.status

    disputed = create_request
    post action_path(disputed, "dispute_responsibility"),
         params: { rationale: "The damage source is still under review." },
         headers: @auth_headers,
         as: :json
    assert_response :success
    assert_equal "disputed", disputed.reload.responsibility_status
  end

  test "approves work and keeps responsibility allocation a separate decision" do
    request = create_request(status: "awaiting_approval")
    lease, tenant = create_tenant_lease
    request.update!(lease: lease)

    post action_path(request, "approve"),
         params: { approved_cost: "300.00" },
         headers: @auth_headers,
         as: :json

    assert_response :success
    request.reload
    assert_equal BigDecimal("300.00"), request.approved_cost
    assert_equal "pending_review", request.responsibility_status
    assert_empty request.cost_allocations

    post action_path(request, "allocations"),
         params: {
           rationale: "Reviewed the lease and supporting evidence.",
           allocations: [
             { responsible_party: "owner", allocated_amount: "100.00", allocation_percentage: "33.33", currency: "ZAR" },
             {
               responsible_party: "tenant",
               allocated_amount: "200.00",
               allocation_percentage: "66.67",
               currency: "ZAR",
               party_id: tenant.id,
               lease_id: lease.id
             }
           ]
         },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal "approved", request.reload.responsibility_status
    assert_equal BigDecimal("300.00"), request.cost_allocations.sum(:allocated_amount)
    assert_equal BigDecimal("100.00"), request.cost_allocations.sum(:allocation_percentage)
  end

  test "requires a tenant party to match the linked lease before approving a tenant allocation" do
    request = create_request(status: "approved", approved_cost: 100)
    lease, tenant = create_tenant_lease
    other_tenant = @organization.parties.create!(party_type: "individual", name: "Different Tenant")
    request.update!(lease: lease)

    post action_path(request, "allocations"),
         params: {
           rationale: "Reviewed allocation.",
           allocations: [{
             responsible_party: "tenant",
             allocated_amount: "100",
             currency: "ZAR",
             lease_id: lease.id
           }]
         },
         headers: @auth_headers,
         as: :json

    assert_response :unprocessable_entity
    assert_empty request.reload.cost_allocations

    post action_path(request, "allocations"),
         params: {
           rationale: "Reviewed allocation.",
           allocations: [{
             responsible_party: "tenant",
             allocated_amount: "100",
             currency: "ZAR",
             party_id: other_tenant.id,
             lease_id: lease.id
           }]
         },
         headers: @auth_headers,
         as: :json

    assert_response :unprocessable_entity
    assert_empty request.reload.cost_allocations
    assert_equal "pending_review", request.responsibility_status

    post action_path(request, "allocations"),
         params: {
           rationale: "Tenant and lease verified.",
           allocations: [{
             responsible_party: "tenant",
             allocated_amount: "100",
             currency: "ZAR",
             party_id: tenant.id,
             lease_id: lease.id
           }]
         },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal tenant.id, request.cost_allocations.sole.party_id
  end

  test "rejects allocations that do not reconcile to the approved amount" do
    request = create_request(status: "approved", approved_cost: 250)

    post action_path(request, "allocations"),
         params: {
           rationale: "Reviewed allocation.",
           allocations: [{ responsible_party: "owner", allocated_amount: "200", currency: "ZAR" }]
         },
         headers: @auth_headers,
         as: :json

    assert_response :unprocessable_entity
    assert_empty request.reload.cost_allocations
    assert_equal "pending_review", request.responsibility_status
  end

  test "rejects malformed allocation amounts without raising an exception" do
    request = create_request(status: "approved", approved_cost: 250)

    post action_path(request, "allocations"),
         params: {
           rationale: "Reviewed allocation.",
           allocations: [{ responsible_party: "owner", allocated_amount: "not-an-amount", currency: "ZAR" }]
         },
         headers: @auth_headers,
         as: :json

    assert_response :unprocessable_entity
    assert_empty request.reload.cost_allocations
  end

  test "records quotations, invoices, and payments as separate entries" do
    request = create_request

    post action_path(request, "financial_entries"),
         params: { financial_entry: { entry_type: "quotation", amount: "20.00", currency: "ZAR", occurred_on: Date.current.to_s } },
         headers: @auth_headers,
         as: :json
    assert_response :created

    post action_path(request, "financial_entries"),
         params: {
           financial_entry: {
             entry_type: "invoice",
             amount: "20.00",
             currency: "ZAR",
             occurred_on: Date.current.to_s,
             invoice_reference: "INV-#{SecureRandom.hex(4)}"
           }
         },
         headers: @auth_headers,
         as: :json
    assert_response :created
    invoice_id = JSON.parse(response.body).fetch("id")

    post action_path(request, "financial_entries"),
         params: {
           financial_entry: {
             entry_type: "payment",
             amount: "20.00",
             currency: "ZAR",
             occurred_on: Date.current.to_s,
             invoice_id: invoice_id
           }
         },
         headers: @auth_headers,
         as: :json
    assert_response :created

    assert_equal %w[invoice payment quotation], request.reload.financial_entries.order(:entry_type).pluck(:entry_type)
    assert_equal 1, request.quotes.count
    assert_equal 1, request.invoices.count
    assert_equal invoice_id, request.payments.sole.invoice_id
    assert request.financial_entries.all? { |entry| entry.type.nil? }
  end

  test "marks a pending payment paid only through its property-scoped endpoint" do
    request = create_request
    invoice = MaintenanceInvoice.create!(
      organization: @organization,
      maintenance_request: request,
      recorded_by: @manager,
      amount: 25,
      currency: "ZAR",
      occurred_on: Date.current,
      invoice_reference: "INV-#{SecureRandom.hex(4)}"
    )
    payment = MaintenancePayment.create!(
      organization: @organization,
      maintenance_request: request,
      invoice: invoice,
      recorded_by: @manager,
      amount: 25,
      currency: "ZAR",
      occurred_on: Date.current,
      status: "pending"
    )

    post "#{requests_path}/#{request.id}/payments/#{payment.id}/mark_paid",
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal "paid", payment.reload.status
    assert_equal BigDecimal("25"), invoice.reload.paid_amount
  end

  test "records typed quotes, invoices and invoice-linked payments" do
    request = create_request
    post "#{requests_path}/#{request.id}/quotes",
         params: { quote: { amount: "40.00", currency: "ZAR", occurred_on: Date.current.to_s, valid_until: 1.week.from_now.to_date.to_s } },
         headers: @auth_headers,
         as: :json
    assert_response :created
    assert_equal "received", JSON.parse(response.body).fetch("status")

    post "#{requests_path}/#{request.id}/invoices",
         params: {
           invoice: {
             amount: "40.00",
             currency: "ZAR",
             occurred_on: Date.current.to_s,
             due_on: 1.week.from_now.to_date.to_s,
             invoice_reference: "INV-#{SecureRandom.hex(4)}"
           }
         },
         headers: @auth_headers,
         as: :json
    assert_response :created
    invoice_id = JSON.parse(response.body).fetch("id")

    post "#{requests_path}/#{request.id}/payments",
         params: {
           payment: {
             amount: "20.00",
             currency: "ZAR",
             occurred_on: Date.current.to_s,
             invoice_id: invoice_id,
             status: "paid"
           }
         },
         headers: @auth_headers,
         as: :json
    assert_response :created

    invoice = request.invoices.sole
    assert_equal BigDecimal("20.00"), invoice.paid_amount
    assert_equal BigDecimal("20.00"), invoice.outstanding_balance
    assert_equal 1, request.quotes.count
    assert_equal 1, request.payments.count
  end

  test "rejects payments that exceed or reference another work order's invoice" do
    request = create_request
    other_request = create_request
    invoice = MaintenanceInvoice.create!(
      organization: @organization,
      maintenance_request: request,
      recorded_by: @manager,
      amount: 10,
      currency: "ZAR",
      occurred_on: Date.current,
      invoice_reference: "INV-#{SecureRandom.hex(4)}"
    )

    post "#{requests_path}/#{request.id}/payments",
         params: {
           payment: {
             amount: "11.00",
             currency: "ZAR",
             occurred_on: Date.current.to_s,
             invoice_id: invoice.id
           }
         },
         headers: @auth_headers,
         as: :json
    assert_response :unprocessable_entity
    assert_empty invoice.payments

    post "#{requests_path}/#{other_request.id}/payments",
         params: {
           payment: {
             amount: "1.00",
             currency: "ZAR",
             occurred_on: Date.current.to_s,
             invoice_id: invoice.id
           }
         },
         headers: @auth_headers,
         as: :json
    assert_response :unprocessable_entity
    assert_empty invoice.payments
  end

  test "typed financial records require an invoice reference and linked invoice payment" do
    request = create_request

    post "#{requests_path}/#{request.id}/invoices",
         params: { invoice: { amount: "10", currency: "ZAR", occurred_on: Date.current.to_s } },
         headers: @auth_headers,
         as: :json
    assert_response :unprocessable_entity

    post "#{requests_path}/#{request.id}/payments",
         params: { payment: { amount: "10", currency: "ZAR", occurred_on: Date.current.to_s } },
         headers: @auth_headers,
         as: :json
    assert_response :unprocessable_entity
  end

  test "assigns only organization users and parties through the property-scoped endpoint" do
    request = create_request
    assignee = @organization.users.create!(
      email: "maintenance.assignee@example.com",
      first_name: "Alex",
      last_name: "Assignee",
      password: "password123"
    )
    @property.property_assignments.create!(
      organization: @organization,
      user: assignee,
      assignment_type: "staff",
      starts_at: 1.hour.ago
    )
    contractor = @organization.parties.create!(name: "Local Contractor", party_type: "contractor")

    post action_path(request, "assign"),
         params: { assignment: { assigned_to_id: assignee.id, contractor_id: contractor.id } },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal assignee.id, request.reload.assigned_to_id
    assert_equal contractor.id, request.contractor_id

    other_organization = Organization.create!(name: "Foreign assignment org #{SecureRandom.hex(4)}")
    foreign_user = other_organization.users.create!(
      email: "foreign-assignee-#{SecureRandom.hex(4)}@example.com",
      first_name: "Fran",
      last_name: "Foreign",
      password: "password123"
    )
    post action_path(request, "assign"),
         params: { assignment: { assigned_to_id: foreign_user.id } },
         headers: @auth_headers,
         as: :json
    assert_response :unprocessable_entity
    assert_equal assignee.id, request.reload.assigned_to_id
  end

  test "verifies resolved work before closing and keeps the combined close path compatible" do
    request = create_request(status: "resolved")

    post action_path(request, "verify"), headers: @auth_headers, as: :json
    assert_response :success
    assert_equal @manager.id, request.reload.verified_by_id

    post action_path(request, "close"), headers: @auth_headers, as: :json
    assert_response :success
    assert_equal "closed", request.reload.status

    unverified_request = create_request(status: "resolved")
    post action_path(unverified_request, "close"), headers: @auth_headers, as: :json
    assert_response :success
    assert_equal @manager.id, unverified_request.reload.verified_by_id
  end

  test "lists and attaches maintenance documents within the assigned property" do
    request = create_request
    file = Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-1.4\n"),
      "application/pdf",
      true,
      original_filename: "invoice.pdf"
    )

    post "#{action_path(request, 'documents')}",
         params: { file: file, document_type: "invoice", title: "Repair invoice" },
         headers: @auth_headers

    assert_response :created
    document_id = JSON.parse(response.body).fetch("id")

    get action_path(request, "documents"), headers: @auth_headers
    assert_response :success
    assert_equal document_id, JSON.parse(response.body).sole.fetch("id")
  end

  test "rejects a work order id belonging to another organization's property" do
    other_organization = Organization.create!(name: "Other maintenance org #{SecureRandom.hex(4)}")
    other_manager = other_organization.users.create!(
      email: "other-manager-#{SecureRandom.hex(4)}@example.com",
      first_name: "Other",
      last_name: "Manager",
      password: "password123"
    )
    other_property = other_organization.properties.create!(name: "Other maintenance property", property_type: "residential")
    other_request = other_property.maintenance_requests.create!(
      organization: other_organization,
      reported_by: other_manager,
      title: "Other request",
      priority: "medium",
      reported_at: Time.current
    )

    get "#{requests_path}/#{other_request.id}", headers: @auth_headers

    assert_response :not_found
  end

  test "only an active property manager can create work orders" do
    viewer = @organization.users.create!(
      email: "maintenance.viewer@example.com",
      first_name: "Val",
      last_name: "Viewer",
      password: "password123"
    )
    @property.property_assignments.create!(
      organization: @organization,
      user: viewer,
      assignment_type: "viewer",
      starts_at: 1.hour.ago
    )
    authenticate_as(viewer)

    post requests_path,
         params: { maintenance_request: { title: "Unauthorized work", priority: "medium" } },
         headers: @auth_headers,
         as: :json

    assert_response :forbidden
  end

  test "records actual cost only when completing work" do
    request = create_request(status: "in_progress")

    patch "#{requests_path}/#{request.id}",
          params: { maintenance_request: { actual_cost: "125.00" } },
          headers: @auth_headers,
          as: :json

    assert_response :success
    assert_nil request.reload.actual_cost

    post action_path(request, "complete"),
         params: { actual_cost: "125.00" },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal BigDecimal("125.00"), request.reload.actual_cost
  end

  test "work orders cannot be read through an unassigned property" do
    other_property = @organization.properties.create!(name: "Unassigned property", property_type: "residential")

    get "/api/v1/properties/#{other_property.id}/maintenance_requests", headers: @auth_headers

    assert_response :not_found
  end

  private

  def create_request(status: "open", approved_cost: nil)
    @property.maintenance_requests.create!(
      organization: @organization,
      reported_by: @manager,
      title: "Maintenance request",
      priority: "medium",
      status: status,
      approved_cost: approved_cost,
      reported_at: Time.current
    )
  end

  def create_tenant_lease
    building = @property.buildings.create!(organization: @organization, name: "Tenant building")
    unit = building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "Tenant unit",
      unit_type: "residential"
    )
    tenant = @organization.parties.create!(party_type: "individual", name: "Maintenance Tenant")
    lease = @property.leases.create!(
      organization: @organization,
      unit: unit,
      tenant: tenant,
      status: "active",
      lease_type: "fixed_term",
      start_date: Date.current,
      end_date: 1.year.from_now.to_date,
      monthly_rent: 1000,
      currency: "ZAR"
    )
    [lease, tenant]
  end

  def requests_path
    "/api/v1/properties/#{@property.id}/maintenance_requests"
  end

  def action_path(request, action)
    "#{requests_path}/#{request.id}/#{action}"
  end

  def authenticate_as(user)
    post api_v1_login_path, params: { email: user.email, password: "password123" }, as: :json
    assert_response :created
    @auth_headers = { "Authorization" => "Bearer #{JSON.parse(response.body).fetch('token')}" }
  end
end
