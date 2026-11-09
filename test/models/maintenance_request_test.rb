require "test_helper"

class MaintenanceRequestTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Maintenance Org #{SecureRandom.hex(4)}")
    @user = @organization.users.create!(
      email: "manager@example.com",
      first_name: "Mary",
      last_name: "Manager",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Maintenance House", property_type: "residential")
  end

  test "creates a valid maintenance request" do
    request = MaintenanceRequest.new(
      organization: @organization,
      property:     @property,
      reported_by:  @user,
      title:        "Leaking tap",
      priority:     "medium",
      status:       "open",
      reported_at:  Time.current
    )
    assert request.valid?, request.errors.full_messages.inspect
  end

  test "requires title and reported_at" do
    request = MaintenanceRequest.new(
      organization: @organization, property: @property, reported_by: @user
    )
    assert_not request.valid?
    assert request.errors[:title].any?
    assert request.errors[:reported_at].any?
  end

  test "validates priority enum" do
    request = MaintenanceRequest.new(
      organization: @organization, property: @property, reported_by: @user,
      title: "Fix roof", reported_at: Time.current, status: "open", priority: "catastrophic"
    )
    assert_not request.valid?
    assert request.errors[:priority].any?
  end

  test "open scope excludes resolved and closed" do
    MaintenanceRequest.create!(
      organization: @organization, property: @property, reported_by: @user,
      title: "Open request", priority: "low", status: "open", reported_at: Time.current
    )
    MaintenanceRequest.create!(
      organization: @organization, property: @property, reported_by: @user,
      title: "Closed request", priority: "low", status: "closed", reported_at: Time.current
    )
    assert_equal 1, MaintenanceRequest.open.count
  end
end
