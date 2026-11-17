require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "management login selects an active organization membership" do
    home = Organization.create!(name: "Login home #{SecureRandom.hex(4)}")
    managed = Organization.create!(name: "Login managed #{SecureRandom.hex(4)}")
    user = create_user(home, "multi-org")
    user.organization_memberships.create!(
      organization: managed,
      role: "administrator",
      status: "active"
    )
    home.parties.create!(name: "Home-only party", party_type: "individual")
    managed.parties.create!(name: "Managed-only party", party_type: "individual")

    post "/api/v1/login", params: {
      email: user.email,
      password: "password123",
      workspace: "management"
    }, as: :json

    assert_response :unauthorized

    post "/api/v1/login", params: {
      email: user.email,
      password: "password123",
      organization_id: managed.id,
      workspace: "management"
    }, as: :json

    assert_response :created
    assert_equal managed.id, response.parsed_body.dig("user", "organization_id")
    assert_equal "administrator", response.parsed_body.dig("user", "membership_role")

    token = response.parsed_body.fetch("token")
    get "/api/v1/parties", headers: bearer_headers(token)

    assert_response :success
    assert_includes response.body, "Managed-only party"
    assert_not_includes response.body, "Home-only party"

    token_payload = Rails.application.message_verifier(:authentication).verified(
      token,
      purpose: :access_token
    )
    delete "/api/v1/logout", headers: bearer_headers(token)
    assert_response :no_content
    assert AccessTokenRevocation.exists?(
      token_id: token_payload["token_id"],
      user_id: user.id
    )

    get "/api/v1/parties", headers: bearer_headers(token)
    assert_response :unauthorized

    # Logout is idempotent and does not disclose whether a token was already revoked.
    delete "/api/v1/logout", headers: bearer_headers(token)
    assert_response :no_content
  end

  test "legacy user-only token is rejected when organization context is ambiguous" do
    home = Organization.create!(name: "Legacy token home #{SecureRandom.hex(4)}")
    managed = Organization.create!(name: "Legacy token managed #{SecureRandom.hex(4)}")
    user = create_user(home, "legacy-multi")
    user.organization_memberships.create!(
      organization: managed,
      role: "member",
      status: "active"
    )
    token = Rails.application.message_verifier(:authentication).generate(
      {
        user_id: user.id,
        token_id: SecureRandom.uuid,
        expires_at: 24.hours.from_now.to_i
      },
      purpose: :access_token,
      expires_in: 24.hours
    )

    get "/api/v1/parties", headers: bearer_headers(token)

    assert_response :unauthorized
  end

  test "tenant workspace does not require an active management membership" do
    organization = Organization.create!(name: "Tenant login #{SecureRandom.hex(4)}")
    manager = create_user(organization, "tenant-manager", organization_role: "administrator")
    tenant = User.create!(
      email: "tenant-user-#{SecureRandom.hex(4)}@example.com",
      first_name: "Test",
      last_name: "Tenant",
      password: "password123",
      skip_initial_organization_membership: true
    )
    tenant.update!(email_verified_at: Time.current)
    assert_empty tenant.organization_memberships

    property = organization.properties.create!(
      name: "Tenant login property",
      property_type: "residential"
    )
    building = property.buildings.create!(organization: organization, name: "Main")
    unit = building.units.create!(
      organization: organization,
      property: property,
      unit_number: "A1",
      unit_type: "residential"
    )
    party = organization.parties.create!(name: "Tenant party", party_type: "individual")
    account = PartyAccount.create!(
      organization: organization,
      user: tenant,
      party: party,
      status: "verified",
      verified_by: manager,
      verified_at: Time.current
    )
    TenantProfile.create!(
      organization: organization,
      party_account: account,
      tenant_reference: "TEN-A1"
    )
    Lease.create!(
      organization: organization,
      property: property,
      unit: unit,
      tenant: party,
      status: "active",
      lease_type: "fixed_term",
      start_date: Date.current,
      end_date: 1.year.from_now.to_date,
      monthly_rent: 1000,
      rent_currency: "ZAR"
    )

    post "/api/v1/login", params: {
      email: tenant.email,
      password: "password123",
      organization_id: organization.id,
      workspace: "tenant"
    }, as: :json

    assert_response :created
    assert_equal "tenant", response.parsed_body.dig("user", "workspace")
    assert_nil response.parsed_body.dig("user", "membership_id")

    token = response.parsed_body.fetch("token")
    get "/api/v1/tenant/dashboard", headers: bearer_headers(token)
    assert_response :success

    get "/api/v1/parties", headers: bearer_headers(token)
    assert_response :forbidden
  end

  private

  def create_user(organization, prefix, organization_role: "member", skip_initial_organization_membership: false)
    organization.users.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "password123",
      organization_role: organization_role,
      skip_initial_organization_membership: skip_initial_organization_membership
    )
  end

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
