require "test_helper"

class TenantIdentityTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Tenant identity #{SecureRandom.hex(4)}")
    @admin = create_user(@organization, "admin", organization_role: "administrator")
    @tenant_user = create_user(@organization, "tenant")
    @tenant_party = @organization.parties.create!(party_type: "individual", name: "Tenant Person")
    @property = @organization.properties.create!(name: "Tenant property", property_type: "residential")
  end

  test "tenant account is linked explicitly rather than by a matching email" do
    user = create_user(@organization, "same-email")
    party = @organization.parties.create!(party_type: "individual", name: "Same Email")

    assert_empty user.party_accounts
    assert_empty party.party_accounts
  end

  test "verified tenant identity and profile must share an organization" do
    account = create_party_account(@tenant_user, @tenant_party)
    profile = TenantProfile.new(organization: @organization, party_account: account, tenant_reference: "TEN-001")
    assert profile.valid?, profile.errors.full_messages.inspect

    other_organization = Organization.create!(name: "Other identity #{SecureRandom.hex(4)}")
    profile.organization = other_organization
    assert_not profile.valid?
    assert profile.errors[:party_account].any?
  end

  test "tenant profile cannot use an unverified party account" do
    pending_account = PartyAccount.create!(
      organization: @organization,
      user: @tenant_user,
      party: @tenant_party,
      status: "pending_verification"
    )
    profile = TenantProfile.new(organization: @organization, party_account: pending_account)

    assert_not profile.valid?
    assert_includes profile.errors[:party_account], "must be verified"
  end

  test "a user cannot create a second tenant profile for another party in the same organization" do
    first_account = create_party_account(@tenant_user, @tenant_party)
    TenantProfile.create!(organization: @organization, party_account: first_account)

    other_party = @organization.parties.create!(party_type: "individual", name: "Mislinked Tenant")
    other_account = create_party_account(@tenant_user, other_party)
    conflicting_profile = TenantProfile.new(organization: @organization, party_account: other_account)

    assert_not conflicting_profile.valid?
    assert conflicting_profile.errors[:party_account].any?
  end

  test "property access is granted only by organization administration, verified ownership, or explicit assignment capability" do
    agent = create_user(@organization, "agent")
    assignment = PropertyAssignment.create!(
      organization: @organization,
      property: @property,
      user: agent,
      assignment_type: "manager",
      starts_at: 1.hour.ago,
      capabilities: []
    )

    assert_not agent.authorized_for_property?(@property, "invite_tenants")
    assignment.update!(capabilities: ["invite_tenants"])
    assert agent.authorized_for_property?(@property, "invite_tenants")
    assert @admin.authorized_for_property?(@property, "invite_tenants")

    owner_party = @organization.parties.create!(party_type: "individual", name: "Verified Owner")
    owner = create_user(@organization, "owner")
    create_party_account(owner, owner_party)
    PropertyOwnership.create!(
      organization: @organization,
      property: @property,
      party: owner_party,
      ownership_percentage: 100,
      start_date: 1.month.ago.to_date,
      verification_status: "verified",
      verified_by: @admin,
      verified_at: Time.current
    )

    assert owner.authorized_for_property?(@property, "propose_lease_renewals")
  end

  test "cross-organization property assignments cannot grant tenant capabilities" do
    other_organization = Organization.create!(name: "Other assignment org #{SecureRandom.hex(4)}")
    other_user = create_user(other_organization, "agent")
    assignment = PropertyAssignment.new(
      organization: @organization,
      property: @property,
      user: other_user,
      assignment_type: "manager",
      starts_at: 1.hour.ago,
      capabilities: ["invite_tenants"]
    )

    assert_not assignment.valid?
    assert assignment.errors[:capabilities].any?
    assert_not other_user.authorized_for_property?(@property, "invite_tenants")
  end

  test "platform administrator access requires an active explicit grant" do
    assert_not @tenant_user.platform_administrator?

    grant = PlatformAdministratorGrant.create!(
      user: @tenant_user,
      granted_by: @admin,
      reason: "Platform support duties"
    )
    assert @tenant_user.platform_administrator?
    assert @tenant_user.authorized_for_property?(@property, "invite_tenants")

    grant.update!(revoked_by: @admin, revoked_at: Time.current)
    assert_not @tenant_user.platform_administrator?
    assert_not @tenant_user.authorized_for_property?(@property, "invite_tenants")
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

  def create_party_account(user, party)
    PartyAccount.create!(
      organization: @organization,
      user: user,
      party: party,
      status: "verified",
      verified_by: @admin,
      verified_at: Time.current
    )
  end
end
