require "test_helper"

class MaintenanceScheduleTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Maintenance schedules #{SecureRandom.hex(4)}")
    @user = @organization.users.create!(
      email: "schedule.manager@example.com",
      first_name: "Sam",
      last_name: "Manager",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Schedule property", property_type: "residential")
    @property.property_assignments.create!(
      organization: @organization,
      user: @user,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
  end

  test "generates a proposed occurrence once and advances the recurring plan" do
    due_on = Date.current - 1.month
    schedule = @property.maintenance_schedules.create!(
      organization: @organization,
      created_by: @user,
      title: "Quarterly pump service",
      priority: "medium",
      frequency: "quarterly",
      starts_on: due_on,
      next_due_on: due_on,
      generation_mode: "proposed"
    )

    assert_difference "MaintenanceRequest.count", 1 do
      MaintenanceScheduleGenerator.call(schedule, through: due_on)
    end
    request = schedule.maintenance_requests.sole
    assert_equal "awaiting_approval", request.status
    assert_equal due_on, request.occurrence_on
    assert_equal due_on.advance(months: 3), schedule.reload.next_due_on

    assert_no_difference "MaintenanceRequest.count" do
      MaintenanceScheduleGenerator.call(schedule, through: due_on)
    end
  end

  test "reminder-only plans do not auto-generate work orders" do
    due_on = Date.current
    schedule = @property.maintenance_schedules.create!(
      organization: @organization,
      created_by: @user,
      title: "Annual safety check",
      priority: "low",
      frequency: "annual",
      starts_on: due_on,
      next_due_on: due_on,
      generation_mode: "reminder_only"
    )

    assert_no_difference "MaintenanceRequest.count" do
      MaintenanceScheduleGenerator.call(schedule, through: due_on)
    end
    assert_equal due_on, schedule.reload.next_due_on

    assert_difference "MaintenanceRequest.count", 1 do
      MaintenanceScheduleGenerator.call(schedule, through: due_on, manual: true)
    end
  end

  test "manually generating a proposed occurrence still requires approval" do
    due_on = Date.current
    schedule = @property.maintenance_schedules.create!(
      organization: @organization,
      created_by: @user,
      title: "Quarterly pump service",
      priority: "medium",
      frequency: "quarterly",
      starts_on: due_on,
      next_due_on: due_on,
      generation_mode: "proposed"
    )

    generated = MaintenanceScheduleGenerator.call(schedule, through: due_on, manual: true)

    assert_equal "awaiting_approval", generated.sole.status
  end
end
