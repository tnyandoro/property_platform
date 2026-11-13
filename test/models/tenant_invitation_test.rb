require "test_helper"

class TenantInvitationTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Invitation org #{SecureRandom.hex(4)}")
    @admin = create_user(@organization, "admin", organization_role: "administrator")
    @property = @organization.properties.create!(name: "Invitation property", property_type: "residential")
    building = @property.buildings.create!(organization: @organization, name: "Main")
    unit = building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "1",
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
      monthly_rent: 5000
    )
  end

  test "invitation is normalized, scoped to the exact lease, and stores a digest" do
    invitation = build_invitation(target_email: "  TENANT@EXAMPLE.COM ")

    assert invitation.valid?, invitation.errors.full_messages.inspect
    assert_equal "tenant@example.com", invitation.target_email
    assert_match(/\A[0-9a-f]{64}\z/, invitation.token_digest)
    assert invitation.valid_for_activation?
  end

  test "invitation rejects an unauthorized inviter and a mismatched tenant or property" do
    unauthorized = create_user(@organization, "unassigned")
    invitation = build_invitation(invited_by: unauthorized)
    assert_not invitation.valid?
    assert invitation.errors[:invited_by].any?

    other_property = @organization.properties.create!(name: "Other property", property_type: "residential")
    invitation = build_invitation(property: other_property)
    assert_not invitation.valid?
    assert invitation.errors[:property].any?

    other_party = @organization.parties.create!(party_type: "individual", name: "Another Tenant")
    invitation = build_invitation(tenant_party: other_party)
    assert_not invitation.valid?
    assert invitation.errors[:tenant_party].any?
  end

  test "expired and consumed invitations cannot be activated" do
    invitation = build_invitation
    invitation.save!
    invitation.update!(expires_at: 1.minute.ago)
    assert_not invitation.valid_for_activation?

    accepted_user = create_user(@organization, "accepted")
    accepted_user.update!(email: invitation.target_email, email_verified_at: Time.current)
    account = PartyAccount.create!(
      organization: @organization,
      user: accepted_user,
      party: @tenant_party,
      status: "verified",
      verified_by: @admin,
      verified_at: Time.current
    )
    TenantProfile.create!(organization: @organization, party_account: account)
    invitation.update!(
      status: "accepted",
      accepted_user: accepted_user,
      accepted_at: Time.current,
      expires_at: 1.day.from_now
    )
    assert_not invitation.valid_for_activation?
  end

  test "duplicate pending invitations for one lease and email are rejected" do
    build_invitation.save!
    duplicate = build_invitation(target_email: "TENANT@example.com")

    assert_not duplicate.valid?
    assert duplicate.errors[:target_email].any?
  end

  test "invitation creation requires a future expiry" do
    invitation = build_invitation(expires_at: 1.minute.ago)

    assert_not invitation.valid?
    assert invitation.errors[:expires_at].any?
  end

  test "revoked invitations cannot be activated" do
    invitation = build_invitation
    invitation.save!
    invitation.update!(status: "revoked", revoked_by: @admin, revoked_at: Time.current)

    assert_not invitation.valid_for_activation?
  end

  private

  def build_invitation(attributes = {})
    TenantInvitation.new(
      {
        organization: @organization,
        tenant_party: @tenant_party,
        property: @property,
        lease: @lease,
        invited_by: @admin,
        target_email: "tenant@example.com",
        token_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
        expires_at: 2.days.from_now
      }.merge(attributes)
    )
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
end
