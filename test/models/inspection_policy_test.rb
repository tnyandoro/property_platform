require "test_helper"

class InspectionPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "InspPolicy Org #{SecureRandom.hex(4)}")

    @manager = @organization.users.create!(
      email: "mgr@inspolicy.example",
      first_name: "Mia", last_name: "Manager", password: "password123"
    )
    @inspector = @organization.users.create!(
      email: "ins@inspolicy.example",
      first_name: "Igor", last_name: "Inspector", password: "password123"
    )
    @bystander = @organization.users.create!(
      email: "by@inspolicy.example",
      first_name: "Barry", last_name: "Bystander", password: "password123"
    )

    @property = @organization.properties.create!(name: "InspPolicy House", property_type: "residential")
    @property.property_assignments.create!(
      organization: @organization, user: @manager,
      assignment_type: "manager", starts_at: 1.hour.ago
    )
    @property.property_assignments.create!(
      organization: @organization, user: @inspector,
      assignment_type: "inspector", starts_at: 1.hour.ago
    )

    @inspection = @organization.inspections.create!(
      property: @property, inspector: @inspector,
      inspection_type: "routine", status: "draft"
    )
  end

  test "assigned inspector can read and create" do
    policy = InspectionPolicy.new(@inspector, @inspection)
    assert policy.index?
    assert policy.show?
    assert policy.create?
  end

  test "inspector can update their own inspection" do
    policy = InspectionPolicy.new(@inspector, @inspection)
    assert policy.update?
  end

  test "manager can update any inspection on their property" do
    policy = InspectionPolicy.new(@manager, @inspection)
    assert policy.update?
  end

  test "bystander cannot read or update" do
    policy = InspectionPolicy.new(@bystander, @inspection)
    assert_not policy.show?
    assert_not policy.update?
  end

  test "locked inspection cannot be locked again" do
    @inspection.update_columns(locked_at: Time.current)
    policy = InspectionPolicy.new(@manager, @inspection)
    assert_not policy.lock?
  end

  test "unlocked inspection can be locked by manager" do
    policy = InspectionPolicy.new(@manager, @inspection)
    assert policy.lock?
  end
end
