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
    assert_empty payload.fetch("cost_allocations")
  end

  test "requires a valid lifecycle transition" do
    request = create_request

    post action_path(request, "start"), headers: @auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "open", request.reload.status
  end

  test "approves work and keeps responsibility allocation a separate decision" do
    request = create_request(status: "awaiting_approval")

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
             { responsible_party: "owner", allocated_amount: "100.00", currency: "ZAR" },
             { responsible_party: "tenant", allocated_amount: "200.00", currency: "ZAR" }
           ]
         },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal "approved", request.reload.responsibility_status
    assert_equal BigDecimal("300.00"), request.cost_allocations.sum(:allocated_amount)
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

    %w[quotation invoice payment].each do |entry_type|
      post action_path(request, "financial_entries"),
           params: {
             financial_entry: {
               entry_type: entry_type,
               amount: "20.00",
               currency: "ZAR",
               occurred_on: Date.current.to_s
             }
           },
           headers: @auth_headers,
           as: :json
      assert_response :created
    end

    assert_equal %w[invoice payment quotation], request.reload.financial_entries.order(:entry_type).pluck(:entry_type)
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
