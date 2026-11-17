require "test_helper"

class OrganizationMembershipTest < ActiveSupport::TestCase
  test "creates an active membership for a new user in their initial organization" do
    organization = Organization.create!(name: "Initial organization")
    user = organization.users.create!(
      email: "member@example.com",
      first_name: "Mira",
      last_name: "Member",
      password: "password123"
    )

    membership = user.organization_memberships.sole
    assert_equal organization, membership.organization
    assert_equal "member", membership.role
    assert_equal "active", membership.status
  end

  test "preserves the legacy organization role when creating the initial membership" do
    organization = Organization.create!(name: "Administrator organization")
    user = organization.users.create!(
      email: "admin@example.com",
      first_name: "Ari",
      last_name: "Admin",
      password: "password123",
      organization_role: "administrator"
    )

    assert user.organization_memberships.sole.administrator?
  end

  test "allows a user to have memberships in more than one organization" do
    first = Organization.create!(name: "First organization")
    second = Organization.create!(name: "Second organization")
    user = first.users.create!(
      email: "multi@example.com",
      first_name: "Morgan",
      last_name: "Multi",
      password: "password123"
    )

    membership = user.organization_memberships.create!(
      organization: second,
      role: "administrator",
      status: "active"
    )

    assert_equal [ first.id, second.id ].sort, user.organization_memberships.active.pluck(:organization_id).sort
    assert membership.administrator?
    assert_equal first, user.reload.organization # Legacy default remains during the transition.
  end

  test "prevents duplicate memberships for the same user and organization" do
    organization = Organization.create!(name: "Unique organization")
    user = organization.users.create!(
      email: "unique@example.com",
      first_name: "Uma",
      last_name: "Unique",
      password: "password123"
    )

    duplicate = user.organization_memberships.new(organization: organization, role: "member")

    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test "rejects unsupported roles and statuses" do
    organization = Organization.create!(name: "Validation organization")
    user = organization.users.create!(
      email: "validation@example.com",
      first_name: "Val",
      last_name: "Validation",
      password: "password123"
    )

    membership = user.organization_memberships.new(
      organization: Organization.create!(name: "Another validation organization"),
      role: "superuser",
      status: "pending"
    )

    assert_not membership.valid?
    assert membership.errors[:role].any?
    assert membership.errors[:status].any?
  end
  test "uses the target organisation membership when checking property capabilities" do
    home = Organization.create!(name: "Home organization")
    managed = Organization.create!(name: "Managed organization")
    user = home.users.create!(
      email: "manager@example.com",
      first_name: "Manny",
      last_name: "Manager",
      password: "password123"
    )
    user.organization_memberships.create!(organization: managed, role: "member", status: "active")
    property = managed.properties.create!(name: "Managed property", property_type: "residential")
    property.property_assignments.create!(
      organization: managed,
      user: user,
      assignment_type: "manager",
      starts_at: Time.current,
      capabilities: ["invite_tenants"]
    )

    assert user.authorized_for_property?(property, "invite_tenants")
    assert_equal managed, user.membership_for(managed.id).organization
  end

  test "an administrator membership grants organisation-level property authority" do
    home = Organization.create!(name: "Administrator home")
    managed = Organization.create!(name: "Administrator managed")
    user = home.users.create!(
      email: "multi-admin@example.com",
      first_name: "Ari",
      last_name: "Admin",
      password: "password123"
    )
    user.organization_memberships.create!(organization: managed, role: "administrator", status: "active")
    property = managed.properties.create!(name: "Admin property", property_type: "residential")

    assert user.authorized_for_property?(property, "invite_tenants")
  end
end
