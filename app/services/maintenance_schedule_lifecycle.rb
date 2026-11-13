class MaintenanceScheduleLifecycle
  class InvalidTransition < StandardError; end

  def self.call(schedule:, action:)
    schedule.with_lock do
      status = case action.to_sym
               when :pause
                 raise InvalidTransition unless schedule.status == "active"
                 "paused"
               when :resume
                 raise InvalidTransition unless schedule.status == "paused"
                 "active"
               when :complete
                 raise InvalidTransition if schedule.status == "completed"
                 "completed"
               else
                 raise ArgumentError, "Unknown maintenance schedule action: #{action}"
               end
      schedule.update!(status: status)
    end
    schedule
  end
end
