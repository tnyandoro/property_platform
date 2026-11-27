require "test_helper"

class InspectionPhotoPolicyTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "PhotoPolicy Org #{SecureRandom.hex(4)}")

    @inspector = @organization.users.create!(
      email: "photo-inspector-#{SecureRandom.hex(4)}@example.com",
      first_name: "Iris",
      last_name: "Inspector",
      password: "password123"
    )

    @bystander = @organization.users.create!(
      email: "photo-bystander-#{SecureRandom.hex(4)}@example.com",
      first_name: "Barry",
      last_name: "Bystander",
      password: "password123"
    )

    @property = @organization.properties.create!(
      name: "PhotoPolicy House",
      property_type: "residential"
    )

    @assignment = @property.property_assignments.create!(
      organization: @organization,
      user: @inspector,
      assignment_type: "inspector",
      starts_at: 1.hour.ago
    )

    @inspection = @organization.inspections.create!(
      property: @property,
      inspector: @inspector,
      inspection_type: "routine",
      status: "draft"
    )
  end

  test "actively assigned inspector can view and add photos" do
    policy = InspectionPhotoPolicy.new(@inspector, @inspection)

    assert policy.index?
    assert policy.create?
  end

  test "unassigned user cannot view or add photos" do
    policy = InspectionPhotoPolicy.new(@bystander, @inspection)

    assert_not policy.index?
    assert_not policy.create?
  end

  test "expired assignment cannot view or add photos" do
    @assignment.update!(ends_at: 1.hour.ago)
    policy = InspectionPhotoPolicy.new(@inspector, @inspection)

    assert_not policy.index?
    assert_not policy.create?
  end

  test "future assignment cannot view or add photos" do
    @assignment.update!(starts_at: 1.hour.from_now)
    policy = InspectionPhotoPolicy.new(@inspector, @inspection)

    assert_not policy.index?
    assert_not policy.create?
  end

  test "photos cannot be added to a locked inspection" do
    @inspection.update!(locked_at: Time.current)
    policy = InspectionPhotoPolicy.new(@inspector, @inspection)

    assert policy.index?
    assert_not policy.create?
  end

  test "photo deletion is not permitted" do
    policy = InspectionPhotoPolicy.new(@inspector, @inspection)

    assert_not policy.destroy?
  end
end
