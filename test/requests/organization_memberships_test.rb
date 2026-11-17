require "test_helper"

class OrganizationMembershipsTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Membership API #{SecureRandom.hex(4)}")
    @admin = create_user(@organization, "admin", role: "administrator")
    @member = create_user(@organization, "member")
  end

  test "organization administrator can list only memberships in the active organization" do
    other = Organization.create!(name: "Other membership organization")
    global_user = create_global_user("other-org")
    global_user.organization_memberships.create!(
      organization: other,
      role: "member",
      status: "active"
    )

    get "/api/v1/organization_memberships", headers: bearer_headers(@admin, @organization)

    assert_response :success
    memberships = response.parsed_body.fetch("memberships")
    assert_equal [ @admin.id, @member.id ].sort, memberships.map { |item| item.dig("user", "id") }.sort
    assert_not_includes memberships.map { |item| item.dig("user", "id") }, global_user.id
  end

  test "administrator can add a global user without a legacy organization" do
    global_user = create_global_user("new-member")

    assert_difference -> { @organization.organization_memberships.count }, 1 do
      post "/api/v1/organization_memberships",
           params: { membership: { user_id: global_user.id, role: "member" } },
           headers: bearer_headers(@admin, @organization),
           as: :json
    end

    assert_response :created
    membership = @organization.organization_memberships.find_by!(user: global_user)
    assert_equal "active", membership.status
    assert_equal "member", membership.role
    assert_nil global_user.reload.legacy_organization
  end

  test "administrator can reactivate a suspended membership" do
    @member.membership_for(@organization).update!(status: "suspended")

    post "/api/v1/organization_memberships",
         params: { membership: { user_id: @member.id, role: "administrator" } },
         headers: bearer_headers(@admin, @organization),
         as: :json

    assert_response :ok
    assert_equal "active", @member.membership_for(@organization).reload.status
    assert @member.membership_for(@organization).administrator?
  end

  test "administrator can update and revoke memberships without deleting history" do
    membership = @member.membership_for(@organization)

    patch "/api/v1/organization_memberships/#{membership.id}",
          params: { membership: { role: "administrator" } },
          headers: bearer_headers(@admin, @organization),
          as: :json

    assert_response :success
    assert_equal "administrator", membership.reload.role

    delete "/api/v1/organization_memberships/#{membership.id}",
           headers: bearer_headers(@admin, @organization)

    assert_response :success
    assert_equal "revoked", membership.reload.status
    assert OrganizationMembership.find_by(id: membership.id)
  end

  test "non-administrator cannot manage organization memberships" do
    get "/api/v1/organization_memberships", headers: bearer_headers(@member, @organization)

    assert_response :forbidden
  end

  test "cannot revoke or demote the last active administrator" do
    membership = @admin.membership_for(@organization)

    patch "/api/v1/organization_memberships/#{membership.id}",
          params: { membership: { role: "member" } },
          headers: bearer_headers(@admin, @organization),
          as: :json

    assert_response :unprocessable_entity
    assert_equal "administrator", membership.reload.role

    delete "/api/v1/organization_memberships/#{membership.id}",
           headers: bearer_headers(@admin, @organization)

    assert_response :unprocessable_entity
    assert_equal "active", membership.reload.status
  end

  test "ambiguous email requires an explicit user id" do
    first_home = Organization.create!(name: "Duplicate email home one")
    second_home = Organization.create!(name: "Duplicate email home two")
    email = "shared-#{SecureRandom.hex(4)}@example.com"
    first = first_home.users.create!(
      email: email,
      first_name: "Shared",
      last_name: "One",
      password: "password123"
    )
    second = second_home.users.create!(
      email: email,
      first_name: "Shared",
      last_name: "Two",
      password: "password123"
    )

    post "/api/v1/organization_memberships",
         params: { membership: { email: email, role: "member" } },
         headers: bearer_headers(@admin, @organization),
         as: :json

    assert_response :conflict
    assert_not @organization.organization_memberships.exists?(user_id: first.id)
    assert_not @organization.organization_memberships.exists?(user_id: second.id)
  end

  private

  def create_user(organization, prefix, role: "member")
    organization.users.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "password123",
      organization_role: role
    )
  end

  def create_global_user(prefix)
    User.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      first_name: "Global",
      last_name: "User",
      password: "password123",
      skip_initial_organization_membership: true
    )
  end

  def bearer_headers(user, organization)
    membership = user.membership_for(organization)
    token = Rails.application.message_verifier(:authentication).generate(
      {
        token_id: SecureRandom.uuid,
        expires_at: 24.hours.from_now.to_i,
        user_id: user.id,
        organization_id: organization.id,
        membership_id: membership.id,
        workspace: "management"
      },
      purpose: :access_token,
      expires_in: 24.hours
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
