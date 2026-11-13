require "test_helper"
require "active_job/test_helper"

class MaintenanceNotificationsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @organization = Organization.create!(name: "Maintenance notifications #{SecureRandom.hex(4)}")
    @manager = @organization.users.create!(
      email: "notification-#{SecureRandom.hex(4)}@example.com",
      first_name: "Mara",
      last_name: "Manager",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Notification property", property_type: "residential")
    @property.property_assignments.create!(
      organization: @organization,
      user: @manager,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
  end

  test "sends a configurable pre-due reminder once per occurrence" do
    due_on = Date.current + 1.day
    schedule = create_schedule(next_due_on: due_on, starts_on: due_on, reminder_days: 2)

    perform_enqueued_jobs do
      2.times { GenerateDueMaintenanceSchedulesJob.perform_now }
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal [@manager.email], ActionMailer::Base.deliveries.sole.to
    assert_equal due_on, schedule.reload.last_reminder_sent_for
  end

  test "sends one overdue reminder for reminder-only schedules without generating work" do
    due_on = Date.current - 1.day
    schedule = create_schedule(
      next_due_on: due_on,
      starts_on: due_on,
      generation_mode: "reminder_only"
    )

    perform_enqueued_jobs do
      2.times { GenerateDueMaintenanceSchedulesJob.perform_now }
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_match "Overdue maintenance", ActionMailer::Base.deliveries.sole.subject
    assert_equal due_on, schedule.reload.last_overdue_notified_for
    assert_empty schedule.maintenance_requests
  end

  test "sends one overdue notification for an unfinished work order" do
    request = @property.maintenance_requests.create!(
      organization: @organization,
      reported_by: @manager,
      assigned_to: @manager,
      title: "Overdue pump repair",
      priority: "high",
      status: "in_progress",
      reported_at: Time.current,
      scheduled_on: Date.current - 3.days,
      target_completion_on: Date.current - 1.day
    )

    perform_enqueued_jobs do
      2.times { GenerateDueMaintenanceSchedulesJob.perform_now }
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_match "Overdue maintenance work", ActionMailer::Base.deliveries.sole.subject
    assert_equal request.target_completion_on, request.reload.overdue_notified_for
  end

  test "does not notify paused schedules" do
    due_on = Date.current - 1.day
    create_schedule(starts_on: due_on, next_due_on: due_on, status: "paused")

    perform_enqueued_jobs { GenerateDueMaintenanceSchedulesJob.perform_now }

    assert_empty ActionMailer::Base.deliveries
  end

  private

  def create_schedule(attributes = {})
    defaults = {
      organization: @organization,
      created_by: @manager,
      title: "Generator service",
      priority: "medium",
      frequency: "monthly",
      starts_on: Date.current,
      next_due_on: Date.current,
      reminder_days: 7
    }
    @property.maintenance_schedules.create!(defaults.merge(attributes))
  end
end
