require "test_helper"

class TenantDashboardTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Tenant dashboard #{SecureRandom.hex(4)}")
    @manager = create_user(@organization, "manager", organization_role: "administrator")
    @tenant_user = create_user(@organization, "tenant")
    @tenant_user.update!(email_verified_at: Time.current)
    @property = @organization.properties.create!(
      name: "Garden House",
      property_type: "residential",
      description: "A quiet family home",
      address_line_1: "14 Garden Road",
      city: "Harare",
      current_value: 250_000
    )
    building = @property.buildings.create!(organization: @organization, name: "Main")
    @unit = building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "4B",
      unit_type: "residential",
      bedrooms: 2,
      bathrooms: 1
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
    @profile = TenantProfile.create!(
      organization: @organization,
      party_account: account,
      tenant_reference: "TEN-004"
    )
    @lease = create_lease(@tenant_party, @unit)
    @request = create_tenant_request(@tenant_user, @tenant_party, @lease, @unit, "Leaking kitchen tap")
  end

  test "tenant login requires organization context when email is ambiguous" do
    other_organization = Organization.create!(name: "Other tenant organization #{SecureRandom.hex(4)}")
    create_user(other_organization, "duplicate", email: @tenant_user.email)

    post "/api/v1/login", params: {
      email: @tenant_user.email,
      password: "password123",
      workspace: "tenant"
    }, as: :json

    assert_response :unauthorized

    post "/api/v1/login", params: {
      email: @tenant_user.email,
      password: "password123",
      organization_id: @organization.id,
      workspace: "tenant"
    }, as: :json

    assert_response :created
    assert_equal "tenant", response.parsed_body.dig("user", "workspace")
  end

  test "tenant portal login requires a verified tenant profile" do
    unlinked_user = create_user(@organization, "unlinked")

    post "/api/v1/login", params: {
      email: unlinked_user.email,
      password: "password123",
      workspace: "tenant"
    }, as: :json

    assert_response :unauthorized
  end

  test "dashboard returns only the authenticated tenant's allowlisted information" do
    shared_document = Document.create!(
      organization: @organization,
      uploaded_by: @manager,
      lease: @lease,
      document_type: "lease",
      title: "Shared lease agreement",
      storage_key: "shared-lease-#{SecureRandom.hex(4)}",
      visibility: "tenant_visible",
      published_by: @manager,
      published_at: Time.current
    )
    Document.create!(
      organization: @organization,
      uploaded_by: @manager,
      lease: @lease,
      document_type: "internal_note",
      title: "Private management note",
      storage_key: "private-lease-#{SecureRandom.hex(4)}"
    )
    published_update = @request.updates.create!(
      organization: @organization,
      author: @manager,
      body: "A technician visit has been arranged.",
      update_type: "scheduled_visit",
      status: "published",
      published_by: @manager,
      published_at: Time.current,
      scheduled_start_at: 2.days.from_now
    )
    @request.updates.create!(
      organization: @organization,
      author: @manager,
      body: "Private internal update",
      update_type: "update",
      status: "draft"
    )
    TenantNotification.create!(
      organization: @organization,
      tenant_profile: @profile,
      lease: @lease,
      notification_type: "lease_expiring",
      title: "Lease reminder",
      body: "Your lease end date is approaching."
    )

    other_user = create_user(@organization, "other-tenant")
    other_party = @organization.parties.create!(party_type: "individual", name: "Another Tenant")
    other_account = PartyAccount.create!(
      organization: @organization,
      user: other_user,
      party: other_party,
      status: "verified",
      verified_by: @manager,
      verified_at: Time.current
    )
    TenantProfile.create!(organization: @organization, party_account: other_account)
    other_unit = @property.buildings.first.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "5A",
      unit_type: "residential"
    )
    other_lease = create_lease(other_party, other_unit)
    create_tenant_request(other_user, other_party, other_lease, other_unit, "Other tenant request")

    get "/api/v1/tenant/dashboard", headers: authenticate_as(@tenant_user)

    assert_response :success
    dashboard = response.parsed_body
    assert_equal "TEN-004", dashboard.dig("profile", "tenant_reference")
    assert_equal 1, dashboard.fetch("tenancies").length
    tenancy = dashboard.fetch("tenancies").first
    assert_equal "Garden House", tenancy.dig("property", "name")
    assert_equal "Harare", tenancy.dig("property", "address", "city")
    assert_equal "4B", tenancy.dig("premises", "unit", "unit_number")
    assert_equal "ZAR", tenancy.dig("lease", "agreed_rent", "currency")
    assert_equal [ shared_document.title ], tenancy.dig("lease", "shared_documents").pluck("title")
    assert_equal [ "Leaking kitchen tap" ], dashboard.fetch("maintenance_requests").pluck("title")
    request_payload = dashboard.fetch("maintenance_requests").first
    assert_equal "submitted", request_payload.fetch("status")
    assert_equal [ published_update.body ], request_payload.fetch("updates").pluck("body")
    assert_equal [ "Lease reminder" ], dashboard.fetch("notifications").pluck("title")
    assert_not_includes response.body, "Private management note"
    assert_not_includes response.body, "Private internal update"
    assert_not_includes response.body, "Other tenant request"
    assert_not_includes response.body, "current_value"
    assert_not_includes response.body, "approved_cost"
    assert_not_includes response.body, "cost_allocations"
  end

  test "dashboard requires authentication" do
    get "/api/v1/tenant/dashboard"

    assert_response :unauthorized
  end

  private

  def create_user(organization, prefix, email: nil, organization_role: "member")
    organization.users.create!(
      email: email || "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "password123",
      organization_role: organization_role
    )
  end

  def create_lease(tenant_party, unit)
    Lease.create!(
      organization: @organization,
      property: @property,
      unit: unit,
      tenant: tenant_party,
      status: "active",
      lease_type: "fixed_term",
      start_date: Date.current,
      end_date: 1.year.from_now.to_date,
      monthly_rent: 5_000,
      rent_currency: "ZAR"
    )
  end

  def create_tenant_request(user, tenant_party, lease, unit, title)
    raise "Lease tenant mismatch" unless lease.tenant_id == tenant_party.id

    MaintenanceRequest.create!(
      organization: @organization,
      property: @property,
      unit: unit,
      lease: lease,
      reported_by: user,
      title: title,
      description: "Water is leaking under the kitchen sink.",
      priority: "medium",
      status: "open",
      source_type: "tenant_request",
      reported_at: Time.current
    )
  end

  def authenticate_as(user)
    token = Rails.application.message_verifier(:authentication).generate(
      { user_id: user.id },
      purpose: :access_token,
      expires_in: 24.hours
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
