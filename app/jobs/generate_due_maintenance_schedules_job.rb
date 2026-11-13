class GenerateDueMaintenanceSchedulesJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.current
    MaintenanceNotificationProcessor.call(today: today)

    MaintenanceSchedule.where(status: "active", generation_mode: %w[automatic proposed])
      .where("next_due_on <= ?", today).find_each do |schedule|
      MaintenanceScheduleGenerator.call(schedule, through: today)
    end
  end
end
