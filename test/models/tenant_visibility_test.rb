require "test_helper"

class TenantVisibilityTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Tenant visibility #{SecureRandom.hex(4)}")
    @admin = create_user(@organization, "admin", organization_role: "administrator")
    @tenant_user = create_user(@organization, "tenant")
    @property = @organization.properties.create!(name: "Visible property", property_type: "residential")
    building = @property.buildings.create!(organization: @organization, name: "Main")
    unit = building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "1",
      unit_type: "residential"
    )
    @tenant_party = @organization.parties.create!(party_type: "individual", name: "Tenant")
    account = PartyAccount.create!(
      organization: @organization,
      user: @tenant_user,
      party: @tenant_party,
      status: "verified",
      verified_by: @admin,
      verified_at: Time.current
    )
    @tenant_profile = TenantProfile.create!(organization: @organization, party_account: account)
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
    @request = MaintenanceRequest.create!(
      organization: @organization,
      property: @property,
      unit: unit,
      lease: @lease,
      reported_by: @tenant_user,
      title: "Leaking tap",
      priority: "medium",
      status: "open",
      source_type: "tenant_request",
      reported_at: Time.current
    )
  end

  test "property photos are private unless explicitly published by an authorized user" do
    photo = PropertyPhoto.new(
      organization: @organization,
      property: @property,
      uploaded_by: @admin
    )
    photo.photo.attach(
      io: StringIO.new("test image"),
      filename: "property.png",
      content_type: "image/png"
    )
    photo.save!
    assert_equal "internal", photo.visibility

    photo.update!(visibility: "tenant_visible", published_by: @admin, published_at: Time.current)
    assert_includes PropertyPhoto.tenant_visible, photo

    unauthorized = create_user(@organization, "unassigned")
    photo.published_by = unauthorized
    assert_not photo.valid?
    assert photo.errors[:published_by].any?
  end

  test "documents remain internal by default and require publication metadata to be shared" do
    document = Document.new(
      organization: @organization,
      uploaded_by: @admin,
      lease: @lease,
      document_type: "lease",
      title: "Lease agreement",
      storage_key: "lease-agreement-test"
    )
    assert_equal "internal", document.visibility
    assert document.valid?, document.errors.full_messages.inspect

    document.visibility = "tenant_visible"
    assert_not document.valid?
    assert document.errors[:visibility].any?

    document.assign_attributes(published_by: @admin, published_at: Time.current)
    assert document.valid?, document.errors.full_messages.inspect
  end

  test "maintenance updates are not tenant-visible until published with authorized metadata" do
    update = MaintenanceRequestUpdate.create!(
      organization: @organization,
      maintenance_request: @request,
      author: @admin,
      body: "The issue is being reviewed."
    )
    assert_empty MaintenanceRequestUpdate.published

    update.update!(
      status: "published",
      published_by: @admin,
      published_at: Time.current
    )
    assert_includes MaintenanceRequestUpdate.published, update

    unauthorized = create_user(@organization, "unassigned")
    update.published_by = unauthorized
    assert_not update.valid?
    assert update.errors[:published_by].any?
  end

  test "tenant requests cannot set management decisions or financial data" do
    submission = MaintenanceRequest.new(
      organization: @organization,
      property: @property,
      unit: @request.unit,
      lease: @lease,
      reported_by: @tenant_user,
      title: "Tenant supplied approval",
      priority: "urgent",
      status: "approved",
      source_type: "tenant_request",
      approved_cost: 100,
      reported_at: Time.current
    )

    assert_not submission.valid?
    assert submission.errors[:status].any?
    assert submission.errors[:base].any?
  end

  test "tenant notification sources must belong to the recipient and be published" do
    update = MaintenanceRequestUpdate.create!(
      organization: @organization,
      maintenance_request: @request,
      author: @admin,
      body: "A visit has been scheduled.",
      update_type: "scheduled_visit",
      status: "published",
      published_by: @admin,
      published_at: Time.current
    )
    notification = TenantNotification.new(
      organization: @organization,
      tenant_profile: @tenant_profile,
      maintenance_request_update: update,
      notification_type: "maintenance_request_update",
      title: "Maintenance update",
      body: "A visit has been scheduled."
    )
    assert notification.valid?, notification.errors.full_messages.inspect

    other_party = @organization.parties.create!(party_type: "individual", name: "Other tenant")
    other_user = create_user(@organization, "other")
    other_account = PartyAccount.create!(
      organization: @organization,
      user: other_user,
      party: other_party,
      status: "verified",
      verified_by: @admin,
      verified_at: Time.current
    )
    other_profile = TenantProfile.create!(organization: @organization, party_account: other_account)
    notification.tenant_profile = other_profile
    assert_not notification.valid?
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
end
