require "test_helper"

class TenantMaintenanceRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Tenant maintenance #{SecureRandom.hex(4)}")
    @manager = create_user(@organization, "manager", organization_role: "administrator")
    @tenant_user = create_user(@organization, "tenant")
    @tenant_user.update!(email_verified_at: Time.current)
    @property = @organization.properties.create!(
      name: "Garden House",
      property_type: "residential",
      address_line_1: "14 Garden Road",
      city: "Harare"
    )
    building = @property.buildings.create!(organization: @organization, name: "Main")
    @unit = building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "4B",
      unit_type: "residential"
    )
    @tenant_party = @organization.parties.create!(party_type: "individual", name: "Tenant Person")
    account = PartyAccount.create!(
      organization: @organization,
      user: @tenant_user,
      party: @tenant_party,
      status: "verified",
      verified_by: @manager,
      verified_at: Time.current
    )
    TenantProfile.create!(organization: @organization, party_account: account)
    @lease = create_lease(@tenant_party, @unit)
  end

  test "tenant can submit a maintenance request against their active lease" do
    assert_difference("MaintenanceRequest.count", 1) do
      post "/api/v1/tenant/maintenance_requests",
        params: {
          maintenance_request: {
            lease_id: @lease.id,
            description: "The kitchen tap is leaking.",
            category: "plumbing",
            priority: "high"
          }
        },
        headers: authenticate_as(@tenant_user, workspace: "tenant"),
        as: :json
    end

    assert_response :created
    payload = response.parsed_body
    request = MaintenanceRequest.order(:created_at).last

    assert_equal @lease.id, payload.fetch("lease_id")
    assert_equal "The kitchen tap is leaking.", payload.fetch("title")
    assert_equal "The kitchen tap is leaking.", payload.fetch("description")
    assert_equal "submitted", payload.fetch("status")
    assert_equal "tenant_request", request.source_type
    assert_equal "open", request.status
    assert_equal @tenant_user.id, request.reported_by_id
    assert_equal @organization.id, request.organization_id
    assert_equal @property.id, request.property_id
    assert_equal @unit.id, request.unit_id
    assert_equal @lease.id, request.lease_id
    assert_equal "undetermined", request.classification
    assert_equal "unknown", request.suggested_responsibility
    assert_equal "pending_review", request.responsibility_status
    assert_nil request.estimated_cost
    assert_nil request.approved_cost
    assert_nil request.actual_cost
    assert_nil request.assigned_to_id
  end

  test "tenant cannot submit against another tenant's lease" do
    other_user = create_user(@organization, "other-tenant")
    other_party = @organization.parties.create!(party_type: "individual", name: "Other Tenant")
    account = PartyAccount.create!(
      organization: @organization,
      user: other_user,
      party: other_party,
      status: "verified",
      verified_by: @manager,
      verified_at: Time.current
    )
    TenantProfile.create!(organization: @organization, party_account: account)
    other_lease = create_lease(other_party, @unit)

    assert_no_difference("MaintenanceRequest.count") do
      post "/api/v1/tenant/maintenance_requests",
        params: {
          maintenance_request: {
            lease_id: other_lease.id,
            description: "Please repair the window."
          }
        },
        headers: authenticate_as(@tenant_user, workspace: "tenant"),
        as: :json
    end

    assert_response :not_found
  end

  test "tenant cannot submit against an expired or future lease" do
    expired_lease = create_lease(@tenant_party, @unit, start_date: 2.years.ago.to_date, end_date: 1.year.ago.to_date)

    assert_no_difference("MaintenanceRequest.count") do
      post "/api/v1/tenant/maintenance_requests",
        params: {
          maintenance_request: {
            lease_id: expired_lease.id,
            description: "Please repair the window."
          }
        },
        headers: authenticate_as(@tenant_user, workspace: "tenant"),
        as: :json
    end

    assert_response :not_found
  end

  test "tenant cannot supply management, property or identity fields" do
    assert_no_difference("MaintenanceRequest.count") do
      post "/api/v1/tenant/maintenance_requests",
        params: {
          maintenance_request: {
            lease_id: @lease.id,
            description: "Please repair the window.",
            property_id: SecureRandom.uuid,
            reported_by_id: @manager.id,
            status: "approved",
            estimated_cost: 500
          }
        },
        headers: authenticate_as(@tenant_user, workspace: "tenant"),
        as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("error"), "property_id"
    assert_includes response.parsed_body.fetch("error"), "status"
  end

  test "tenant can list and view only their own submitted requests" do
    own_request = create_tenant_request(@tenant_user, @tenant_party, @lease, "Leaking tap")
    other_user = create_user(@organization, "other-tenant")
    other_party = @organization.parties.create!(party_type: "individual", name: "Other Tenant")
    account = PartyAccount.create!(
      organization: @organization,
      user: other_user,
      party: other_party,
      status: "verified",
      verified_by: @manager,
      verified_at: Time.current
    )
    TenantProfile.create!(organization: @organization, party_account: account)
    other_lease = create_lease(other_party, @unit)
    other_request = create_tenant_request(other_user, other_party, other_lease, "Other tenant request")

    headers = authenticate_as(@tenant_user, workspace: "tenant")
    get "/api/v1/tenant/maintenance_requests", headers: headers

    assert_response :success
    assert_equal [own_request.id], response.parsed_body.pluck("id")

    get "/api/v1/tenant/maintenance_requests/#{own_request.id}", headers: headers
    assert_response :success
    assert_equal own_request.id, response.parsed_body.fetch("id")

    get "/api/v1/tenant/maintenance_requests/#{other_request.id}", headers: headers
    assert_response :not_found
  end

  test "management workspace token cannot use tenant maintenance endpoints" do
    post "/api/v1/tenant/maintenance_requests",
      params: {
        maintenance_request: {
          lease_id: @lease.id,
          description: "Please repair the window."
        }
      },
      headers: authenticate_as(@tenant_user, workspace: "management"),
      as: :json

    assert_response :forbidden
  end

  test "tenant must provide a description and an eligible lease" do
    assert_no_difference("MaintenanceRequest.count") do
      post "/api/v1/tenant/maintenance_requests",
        params: { maintenance_request: { lease_id: @lease.id, description: " " } },
        headers: authenticate_as(@tenant_user, workspace: "tenant"),
        as: :json
    end

    assert_response :unprocessable_entity
  end

  private

  def create_user(organization, prefix, organization_role: "member")
    organization.users.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "password123",
      organization_role: organization_role
    )
  end

  def create_lease(tenant_party, unit, start_date: Date.current, end_date: 1.year.from_now.to_date)
    Lease.create!(
      organization: @organization,
      property: @property,
      unit: unit,
      tenant: tenant_party,
      status: "active",
      lease_type: "fixed_term",
      start_date: start_date,
      end_date: end_date,
      monthly_rent: 5_000,
      rent_currency: "ZAR"
    )
  end

  def create_tenant_request(user, tenant_party, lease, description)
    MaintenanceRequest.create!(
      organization: @organization,
      property: @property,
      unit: lease.unit,
      lease: lease,
      reported_by: user,
      title: description,
      description: description,
      priority: "medium",
      status: "open",
      source_type: "tenant_request",
      reported_at: Time.current
    )
  end

  def authenticate_as(user, workspace:)
    membership = user.membership_for(@organization)
    payload = {
      token_id: SecureRandom.uuid,
      expires_at: 24.hours.from_now.to_i,
      user_id: user.id,
      organization_id: @organization.id,
      workspace: workspace
    }
    payload[:membership_id] = membership.id if workspace == "management" && membership
    token = Rails.application.message_verifier(:authentication).generate(
      payload,
      purpose: :access_token,
      expires_in: 24.hours
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
