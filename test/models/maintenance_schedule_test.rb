require "test_helper"

class MaintenanceScheduleTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

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
    assert_equal "unknown", request.suggested_responsibility
    assert_equal due_on.advance(months: 3), schedule.reload.next_due_on

    schedule.update!(next_due_on: due_on)
    assert_no_difference "MaintenanceRequest.count" do
      assert_empty MaintenanceScheduleGenerator.call(schedule, through: due_on)
    end
  end

  test "monthly recurrence stays anchored to the original day at month boundaries" do
    schedule = create_schedule(
      frequency: "monthly",
      starts_on: Date.new(2026, 1, 31),
      next_due_on: Date.new(2026, 1, 31)
    )

    february_due = schedule.next_due_date(Date.new(2026, 1, 31))
    assert_equal Date.new(2026, 2, 28), february_due
    assert_equal Date.new(2026, 3, 31), schedule.next_due_date(february_due)

    leap_year_schedule = create_schedule(
      frequency: "annual",
      starts_on: Date.new(2024, 2, 29),
      next_due_on: Date.new(2024, 2, 29)
    )
    assert_equal Date.new(2025, 2, 28), leap_year_schedule.next_due_date(Date.new(2024, 2, 29))
    assert_equal Date.new(2026, 2, 28), leap_year_schedule.next_due_date(Date.new(2025, 2, 28))
  end

  test "supports every standard and custom interval" do
    date = Date.new(2026, 1, 15)
    expected = {
      "daily" => Date.new(2026, 1, 16),
      "weekly" => Date.new(2026, 1, 22),
      "monthly" => Date.new(2026, 2, 15),
      "quarterly" => Date.new(2026, 4, 15),
      "semi_annual" => Date.new(2026, 7, 15),
      "annual" => Date.new(2027, 1, 15)
    }

    expected.each do |frequency, next_date|
      schedule = create_schedule(frequency: frequency, starts_on: date, next_due_on: date)
      assert_equal next_date, schedule.next_due_date(date), "#{frequency} recurrence"
    end

    custom_days = create_schedule(
      frequency: "custom",
      starts_on: date,
      next_due_on: date,
      interval_value: 10,
      interval_unit: "day"
    )
    assert_equal Date.new(2026, 1, 25), custom_days.next_due_date(date)

    custom_months = create_schedule(
      frequency: "custom",
      starts_on: date,
      next_due_on: date,
      interval_months: 2
    )
    assert_equal Date.new(2026, 3, 15), custom_months.next_due_date(date)
  end

  test "includes the end date boundary and stops before later occurrences" do
    schedule = create_schedule(
      frequency: "monthly",
      starts_on: Date.new(2026, 1, 31),
      next_due_on: Date.new(2026, 1, 31),
      ends_on: Date.new(2026, 4, 30)
    )

    assert_equal(
      [Date.new(2026, 1, 31), Date.new(2026, 2, 28), Date.new(2026, 3, 31), Date.new(2026, 4, 30)],
      schedule.due_dates_through(Date.new(2026, 4, 30))
    )
    assert_equal(
      [Date.new(2026, 1, 31), Date.new(2026, 2, 28), Date.new(2026, 3, 31)],
      schedule.due_dates_through(Date.new(2026, 4, 29))
    )
  end

  test "paused schedules do not generate or advance" do
    due_on = Date.current - 1.day
    schedule = create_schedule(
      frequency: "monthly",
      starts_on: due_on,
      next_due_on: due_on,
      status: "paused"
    )

    assert_no_difference "MaintenanceRequest.count" do
      assert_empty MaintenanceScheduleGenerator.call(schedule, through: due_on)
    end
    assert_equal due_on, schedule.reload.next_due_on
  end

  test "one-time schedule copies its target date and completes without deleting history" do
    due_on = Date.current
    target_on = due_on + 5.days
    schedule = create_schedule(
      frequency: "once",
      starts_on: due_on,
      next_due_on: due_on,
      target_completion_on: target_on
    )

    generated = MaintenanceScheduleGenerator.call(schedule, through: due_on)

    assert_equal "completed", schedule.reload.status
    assert_equal 1, schedule.maintenance_requests.count
    assert_equal due_on, generated.sole.scheduled_on
    assert_equal target_on, generated.sole.target_completion_on
  end

  test "automatic recurring work remains available after an occurrence is completed" do
    due_on = Date.current
    schedule = create_schedule(
      frequency: "monthly",
      starts_on: due_on,
      next_due_on: due_on,
      generation_mode: "automatic"
    )

    occurrence = MaintenanceScheduleGenerator.call(schedule, through: due_on).sole

    assert_equal "open", occurrence.status
    assert_equal "active", schedule.reload.status
    assert_equal due_on.advance(months: 1), schedule.next_due_on

    occurrence.update!(status: "resolved", resolved_at: Time.current)

    assert_equal "active", schedule.reload.status
    assert_equal 1, schedule.maintenance_requests.count
  end

  test "one-time target completion cannot precede its due date" do
    due_on = Date.current
    schedule = @property.maintenance_schedules.new(
      organization: @organization,
      created_by: @user,
      title: "One-time inspection",
      priority: "medium",
      frequency: "once",
      starts_on: due_on,
      next_due_on: due_on,
      target_completion_on: due_on - 1.day
    )

    assert_not schedule.valid?
    assert schedule.errors[:target_completion_on].any?
  end

  test "date-only schedules use the configured Rails time zone at day boundaries" do
    Time.use_zone("Pacific/Kiritimati") do
      travel_to(Time.utc(2026, 1, 1, 12, 30)) do
        due_on = Date.new(2026, 1, 2)
        schedule = create_schedule(starts_on: due_on, next_due_on: due_on)

        assert_equal due_on, Date.current
        assert_equal [due_on], schedule.due_dates_through(Date.current)
      end
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

  private

  def create_schedule(attributes = {})
    defaults = {
      organization: @organization,
      created_by: @user,
      title: "Test maintenance plan",
      priority: "medium",
      frequency: "quarterly",
      starts_on: Date.current,
      next_due_on: Date.current
    }
    @property.maintenance_schedules.create!(defaults.merge(attributes))
  end
end
