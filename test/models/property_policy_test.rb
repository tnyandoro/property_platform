require "test_helper"

class PropertyPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Policy Org #{SecureRandom.hex(4)}")
    @other_org    = Organization.create!(name: "Other Org #{SecureRandom.hex(4)}")

    @manager = @organization.users.create!(
      email: "manager@policy.example",
      first_name: "Mike", last_name: "Manager", password: "password123"
    )
    @agent = @organization.users.create!(
      email: "agent@policy.example",
      first_name: "Amy", last_name: "Agent", password: "password123"
    )
    @outsider = @other_org.users.create!(
      email: "out@other.example",
      first_name: "Owen", last_name: "Outsider", password: "password123"
    )

    @property = @organization.properties.create!(name: "Policy House", property_type: "residential")
    @property.property_assignments.create!(
      organization: @organization, user: @manager,
      assignment_type: "manager", starts_at: 1.hour.ago
    )
    @property.property_assignments.create!(
      organization: @organization, user: @agent,
      assignment_type: "inspector", starts_at: 1.hour.ago
    )
  end

  test "manager can show, update, and destroy" do
    policy = PropertyPolicy.new(@manager, @property)
    assert policy.show?
    assert policy.update?
    assert policy.destroy?
  end

  test "agent can show but not update or destroy" do
    policy = PropertyPolicy.new(@agent, @property)
    assert policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "outsider from another org cannot do anything" do
    policy = PropertyPolicy.new(@outsider, @property)
    assert_not policy.show?
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "unassigned user in same org cannot show" do
    unassigned = @organization.users.create!(
      email: "nobody@policy.example",
      first_name: "No", last_name: "Body", password: "password123"
    )
    policy = PropertyPolicy.new(unassigned, @property)
    assert_not policy.show?
  end
end
