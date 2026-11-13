class GenerateDueMaintenanceSchedulesJob < ApplicationJob
  queue_as :default

  def perform
    MaintenanceSchedule.due.where.not(generation_mode: "reminder_only").find_each do |schedule|
      MaintenanceScheduleGenerator.call(schedule)
    end
  end
end
