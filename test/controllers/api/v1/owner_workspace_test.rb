require "test_helper"

class OwnerWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Owner workspace #{SecureRandom.hex(4)}")
    @administrator = @organization.users.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      first_name: "Org",
      last_name: "Admin",
      password: "password123",
      organization_role: "administrator"
    )
    @owner = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      first_name: "Property",
      last_name: "Owner",
      password: "password123",
      skip_initial_organization_membership: true,
      email_verified_at: Time.current
    )
    @party = @organization.parties.create!(party_type: "individual", name: "Owner Party")
    PartyAccount.create!(
      organization: @organization,
      user: @owner,
      party: @party,
      status: "verified",
      verified_by: @administrator,
      verified_at: Time.current
    )
    @property = @organization.properties.create!(
      name: "Owner property",
      property_type: "residential",
      address_line_1: "10 Main Road",
      city: "Johannesburg",
      country: "South Africa"
    )
    PropertyOwnership.create!(
      organization: @organization,
      property: @property,
      party: @party,
      ownership_percentage: 75,
      start_date: 1.month.ago.to_date,
      verification_status: "verified",
      verified_by: @administrator,
      verified_at: Time.current
    )
  end

  test "independent verified owner can log in and view only their verified portfolio" do
    assert_empty @owner.organization_memberships

    post "/api/v1/login", params: {
      email: @owner.email,
      password: "password123",
      workspace: "owner",
      organization_id: @organization.id
    }, as: :json

    assert_response :created
    token = response.parsed_body.fetch("token")

    get "/api/v1/owner/dashboard", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    body = response.parsed_body
    assert_equal 1, body.dig("portfolio", "property_count")
    assert_equal 1, body.dig("portfolio", "ownership_count")
    assert_equal @property.id, body.dig("ownerships", 0, "property", "id")
    assert_equal 75, body.dig("ownerships", 0, "ownership_percentage").to_i
  end

  test "owner workspace cannot access management endpoints" do
    post "/api/v1/login", params: {
      email: @owner.email,
      password: "password123",
      workspace: "owner",
      organization_id: @organization.id
    }, as: :json

    token = response.parsed_body.fetch("token")
    get "/api/v1/parties", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :forbidden
  end

  test "owner login requires organisation context when verified ownership spans organisations" do
    other_organization = Organization.create!(name: "Second owner org #{SecureRandom.hex(4)}")
    other_admin = other_organization.users.create!(
      email: "second-admin-#{SecureRandom.hex(4)}@example.com",
      first_name: "Second",
      last_name: "Admin",
      password: "password123",
      organization_role: "administrator"
    )
    other_party = other_organization.parties.create!(party_type: "individual", name: "Owner Party")
    PartyAccount.create!(
      organization: other_organization,
      user: @owner,
      party: other_party,
      status: "verified",
      verified_by: other_admin,
      verified_at: Time.current
    )
    other_property = other_organization.properties.create!(name: "Second property", property_type: "residential")
    PropertyOwnership.create!(
      organization: other_organization,
      property: other_property,
      party: other_party,
      ownership_percentage: 100,
      start_date: 1.month.ago.to_date,
      verification_status: "verified",
      verified_by: other_admin,
      verified_at: Time.current
    )

    post "/api/v1/login", params: {
      email: @owner.email,
      password: "password123",
      workspace: "owner"
    }, as: :json

    assert_response :unauthorized
  end
end
