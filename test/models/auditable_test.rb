require "test_helper"

class AuditableTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Audit Org #{SecureRandom.hex(4)}")
    @user = @organization.users.create!(
      email: "auditor@example.com",
      first_name: "Alice",
      last_name: "Auditor",
      password: "password123"
    )
    Current.user = @user
  end

  teardown { Current.user = nil }

  test "creates an audit log on property create" do
    assert_difference "AuditLog.count", 1 do
      @organization.properties.create!(name: "Audited Property", property_type: "residential")
    end

    log = AuditLog.last
    assert_equal "create",   log.action
    assert_equal "Property", log.auditable_type
    assert_equal @user,      log.actor
  end

  test "creates an audit log on property update" do
    property = @organization.properties.create!(name: "Before", property_type: "residential")
    assert_difference "AuditLog.count", 1 do
      property.update!(name: "After")
    end

    log = AuditLog.last
    assert_equal "update",                   log.action
    assert_includes log.changes_payload["name"], "Before"
    assert_includes log.changes_payload["name"], "After"
  end

  test "creates an audit log on property destroy" do
    property = @organization.properties.create!(name: "Doomed", property_type: "residential")
    assert_difference "AuditLog.count", 1 do
      property.destroy!
    end

    assert_equal "destroy", AuditLog.last.action
  end

  test "creates an audit log for inspection lifecycle" do
    property = @organization.properties.create!(name: "Inspect Me", property_type: "residential")
    inspection = nil
    assert_difference "AuditLog.count", 1 do
      inspection = @organization.inspections.create!(
        property: property, inspector: @user, inspection_type: "routine", status: "draft"
      )
    end

    assert_equal "Inspection", AuditLog.last.auditable_type
    assert_equal inspection.id, AuditLog.last.auditable_id
  end
end
