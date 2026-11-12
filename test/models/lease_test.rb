require "test_helper"

class LeaseTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Lease Org #{SecureRandom.hex(4)}")
    @user = @organization.users.create!(
      email: "landlord@example.com",
      first_name: "Larry",
      last_name: "Landlord",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Lease House", property_type: "residential")
    @building = @property.buildings.create!(organization: @organization, name: "Main")
    @unit     = @building.units.create!(
      organization: @organization, property: @property,
      unit_number: "1", unit_type: "residential"
    )
    @tenant = @organization.parties.create!(party_type: "individual", name: "John Doe")
  end

  test "creates a valid lease" do
    lease = Lease.new(
      organization: @organization,
      property:     @property,
      unit:         @unit,
      tenant:       @tenant,
      status:       "draft",
      lease_type:   "fixed_term",
      start_date:   Date.current,
      end_date:     1.year.from_now.to_date,
      monthly_rent: 5000
    )
    assert lease.valid?, lease.errors.full_messages.inspect
  end

  test "requires start_date and monthly_rent" do
    lease = Lease.new(organization: @organization, property: @property, unit: @unit, tenant: @tenant)
    assert_not lease.valid?
    assert_includes lease.errors[:start_date], "can't be blank"
    assert_includes lease.errors[:end_date], "can't be blank"
    assert_includes lease.errors[:monthly_rent], "can't be blank"
  end

  test "rejects an end date before the start date" do
    lease = Lease.new(
      organization: @organization,
      property: @property,
      unit: @unit,
      tenant: @tenant,
      start_date: Date.current,
      end_date: 1.day.ago.to_date,
      monthly_rent: 5000
    )

    assert_not lease.valid?
    assert_includes lease.errors[:end_date], "cannot be before the lease start date"
  end

  test "validates status" do
    lease = Lease.new(
      organization: @organization, property: @property, unit: @unit, tenant: @tenant,
      start_date: Date.current, monthly_rent: 5000, status: "banana"
    )
    assert_not lease.valid?
    assert lease.errors[:status].any?
  end

  test "active scope returns only active leases" do
    Lease.create!(
      organization: @organization, property: @property, unit: @unit, tenant: @tenant,
      status: "active", lease_type: "fixed_term", start_date: Date.current,
      end_date: 1.year.from_now.to_date, monthly_rent: 5000
    )
    Lease.create!(
      organization: @organization, property: @property, unit: @unit, tenant: @tenant,
      status: "expired", lease_type: "fixed_term", start_date: 1.year.ago,
      end_date: 1.day.ago.to_date, monthly_rent: 4000
    )
    assert_equal 1, Lease.active.count
  end
end
