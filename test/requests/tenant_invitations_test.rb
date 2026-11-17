require "test_helper"

class TenantInvitationsTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @organization = Organization.create!(name: "Invitations #{SecureRandom.hex(4)}")
    @admin = create_user(@organization, "admin", organization_role: "administrator")
    @property = @organization.properties.create!(
      name: "Invitation House",
      property_type: "residential",
      address_line_1: "10 Garden Road",
      city: "Harare"
    )
    building = @property.buildings.create!(organization: @organization, name: "Main")
    unit = building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "A1",
      unit_type: "residential"
    )
    @tenant_party = @organization.parties.create!(party_type: "individual", name: "Invited Tenant")
    @lease = Lease.create!(
      organization: @organization,
      property: @property,
      unit: unit,
      tenant: @tenant_party,
      status: "active",
      lease_type: "fixed_term",
      start_date: Date.current,
      end_date: 1.year.from_now.to_date,
      monthly_rent: 5000,
      rent_currency: "ZAR"
    )
  end

  test "management administrator can invite a tenant and the email contains an activation link" do
    assert_difference("TenantInvitation.count", 1) do
      post "/api/v1/tenant_invitations",
        params: { tenant_invitation: { lease_id: @lease.id, email: "NEW.TENANT@example.com" } },
        headers: authenticate_as(@admin, workspace: "management"),
        as: :json
    end

    assert_response :created
    invitation = TenantInvitation.order(:created_at).last
    assert_equal "new.tenant@example.com", invitation.target_email
    assert_equal "pending", invitation.status
    assert_equal 1, ActionMailer::Base.deliveries.length
    mail = ActionMailer::Base.deliveries.last
    assert_equal ["new.tenant@example.com"], mail.to
    assert_includes mail.from.join, "estate360@saraphim.co.za"
    assert_match(/accept-tenant-invitation\?token=/, mail.body.encoded)
  end

  test "tenant can preview and accept an invitation then sign in" do
    token = create_invitation_token
    get "/api/v1/tenant/invitations/#{token}"
    assert_response :success
    assert_equal "new.tenant@example.com", response.parsed_body.fetch("email")
    assert_equal "Invitation House", response.parsed_body.fetch("property")

    post "/api/v1/tenant/invitations/#{token}/accept",
      params: {
        user: {
          first_name: "New",
          last_name: "Tenant",
          password: "StrongPassword123!",
          password_confirmation: "StrongPassword123!"
        }
      },
      as: :json

    assert_response :created
    user = User.find_by!(email: "new.tenant@example.com")
    assert user.email_verified_at.present?
    assert user.tenant_profiles.exists?(organization_id: @organization.id)
    assert_equal "accepted", TenantInvitation.find_by!(target_email: user.email).status

    post "/api/v1/login",
      params: { email: user.email, password: "StrongPassword123!", workspace: "tenant", organization_id: @organization.id },
      as: :json
    assert_response :created
    assert_equal "tenant", response.parsed_body.dig("user", "workspace")
  end

  test "an invitation cannot be accepted twice" do
    token = create_invitation_token
    payload = {
      user: {
        first_name: "New",
        last_name: "Tenant",
        password: "StrongPassword123!",
        password_confirmation: "StrongPassword123!"
      }
    }

    post "/api/v1/tenant/invitations/#{token}/accept", params: payload, as: :json
    assert_response :created

    post "/api/v1/tenant/invitations/#{token}/accept", params: payload, as: :json
    assert_response :not_found
  end

  test "non-management users cannot create tenant invitations" do
    tenant_user = create_user(@organization, "tenant")
    post "/api/v1/tenant_invitations",
      params: { tenant_invitation: { lease_id: @lease.id, email: "new.tenant@example.com" } },
      headers: authenticate_as(tenant_user, workspace: "management"),
      as: :json

    assert_response :unauthorized
  end

  private

  def create_invitation_token
    token = SecureRandom.urlsafe_base64(32)
    TenantInvitation.create!(
      organization: @organization,
      tenant_party: @tenant_party,
      property: @property,
      lease: @lease,
      invited_by: @admin,
      target_email: "new.tenant@example.com",
      token_digest: Digest::SHA256.hexdigest(token),
      expires_at: 7.days.from_now
    )
    token
  end

  def create_user(organization, prefix, organization_role: "member")
    organization.users.create!(
      email: "#{prefix}-#{SecureRandom.hex(4)}@example.com",
      first_name: "Test",
      last_name: "User",
      password: "password123",
      organization_role: organization_role
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
