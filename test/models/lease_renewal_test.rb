require "test_helper"

class LeaseRenewalTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Renewal org #{SecureRandom.hex(4)}")
    @admin = create_user(@organization, "admin", organization_role: "administrator")
    @tenant_user = create_user(@organization, "tenant")
    @property = @organization.properties.create!(name: "Renewal property", property_type: "residential")
    building = @property.buildings.create!(organization: @organization, name: "Main")
    @unit = building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "1",
      unit_type: "residential"
    )
    @tenant_party = @organization.parties.create!(party_type: "individual", name: "Lease Tenant")
    account = PartyAccount.create!(
      organization: @organization,
      user: @tenant_user,
      party: @tenant_party,
      status: "verified",
      verified_by: @admin,
      verified_at: Time.current
    )
    @tenant_profile = TenantProfile.create!(organization: @organization, party_account: account)
    @lease = create_lease(
      start_date: 1.year.ago.to_date,
      end_date: 2.months.from_now.to_date,
      monthly_rent: 5000
    )
  end

  test "renewal proposal versions retain offered terms and tenant acceptance" do
    proposal = LeaseRenewalProposal.create!(
      organization: @organization,
      lease: @lease,
      created_by: @admin,
      proposed_start_date: @lease.end_date + 1,
      proposed_end_date: @lease.end_date + 1.year,
      proposed_monthly_rent: 5500,
      rent_currency: "ZAR",
      status: "offered",
      expires_at: 7.days.from_now
    )
    assert_equal 1, proposal.version_number

    successor = create_lease(
      previous_lease: @lease,
      start_date: proposal.proposed_start_date,
      end_date: proposal.proposed_end_date,
      monthly_rent: proposal.proposed_monthly_rent,
      rent_currency: proposal.rent_currency
    )
    proposal.update!(
      status: "accepted",
      responded_by: @tenant_user,
      responded_at: Time.current,
      resulting_lease: successor
    )

    assert_equal "accepted", proposal.reload.status
    assert_equal @lease, successor.previous_lease
    assert_not @lease.update(monthly_rent: 6000)
    assert @lease.errors[:base].any?
  end

  test "renewal proposal dates must follow the existing lease" do
    proposal = LeaseRenewalProposal.new(
      organization: @organization,
      lease: @lease,
      created_by: @admin,
      proposed_start_date: @lease.end_date,
      proposed_end_date: @lease.end_date + 1.year,
      proposed_monthly_rent: 5500,
      rent_currency: "ZAR"
    )

    assert_not proposal.valid?
    assert proposal.errors[:proposed_start_date].any?
  end

  test "tenant cannot accept a renewal after its offer expires" do
    proposal = LeaseRenewalProposal.create!(
      organization: @organization,
      lease: @lease,
      created_by: @admin,
      proposed_start_date: @lease.end_date + 1,
      proposed_end_date: @lease.end_date + 1.year,
      proposed_monthly_rent: 5500,
      rent_currency: "ZAR",
      status: "offered",
      expires_at: 7.days.from_now
    )
    successor = create_lease(
      previous_lease: @lease,
      start_date: proposal.proposed_start_date,
      end_date: proposal.proposed_end_date,
      monthly_rent: proposal.proposed_monthly_rent
    )
    proposal.assign_attributes(
      status: "accepted",
      expires_at: 1.day.ago,
      responded_by: @tenant_user,
      responded_at: Time.current,
      resulting_lease: successor
    )

    assert_not proposal.valid?
    assert proposal.errors[:responded_at].any?
  end

  test "tenant extension requests are tied to the submitting verified profile" do
    request = LeaseExtensionRequest.new(
      organization: @organization,
      lease: @lease,
      tenant_profile: @tenant_profile,
      requested_by: @tenant_user,
      requested_end_date: @lease.end_date + 3.months,
      message: "I would like to extend the lease."
    )
    assert request.valid?, request.errors.full_messages.inspect

    other_profile_user = create_user(@organization, "other")
    request.requested_by = other_profile_user
    assert_not request.valid?
    assert request.errors[:requested_by].any?
  end

  test "expired lease terms cannot be edited in place" do
    expired_lease = create_lease(
      status: "expired",
      start_date: 2.years.ago.to_date,
      end_date: 1.day.ago.to_date,
      monthly_rent: 4500
    )

    assert_not expired_lease.update(monthly_rent: 4700)
    assert expired_lease.errors[:base].any?
  end

  private

  def create_lease(attributes = {})
    Lease.create!(
      {
        organization: @organization,
        property: @property,
        unit: @unit,
        tenant: @tenant_party,
        status: "active",
        lease_type: "fixed_term",
        start_date: Date.current,
        end_date: 1.year.from_now.to_date,
        monthly_rent: 5000,
        rent_currency: "ZAR"
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
