class MaintenanceScheduleGenerator
  def self.call(schedule, through: Date.current, manual: false)
    new(schedule, through: through, manual: manual).call
  end

  def initialize(schedule, through:, manual:)
    @schedule = schedule
    @through = through
    @manual = manual
  end

  def call
    generated = []
    schedule.with_lock do
      return generated unless schedule.status == "active"
      return generated if schedule.generation_mode == "reminder_only" && !manual

      due_dates = schedule.due_dates_through(through)
      due_dates.each do |due_on|
        request = schedule.maintenance_requests.create_or_find_by!(occurrence_on: due_on) do |occurrence|
          occurrence.assign_attributes(
            organization: schedule.organization,
            property: schedule.property,
            unit: schedule.unit || schedule.room&.unit,
            room: schedule.room,
            assigned_to: schedule.assigned_to,
            contractor: schedule.contractor,
            reported_by: schedule.created_by,
            title: schedule.title,
            description: schedule.description,
            category: schedule.category,
            priority: schedule.priority,
            classification: schedule.classification,
            suggested_responsibility: generated_responsibility,
            estimated_cost: schedule.estimated_cost,
            currency: schedule.currency,
            reported_at: due_on.in_time_zone,
            scheduled_on: due_on,
            target_completion_on: schedule.frequency == "once" ? schedule.target_completion_on : nil,
            status: schedule.generation_mode == "proposed" ? "awaiting_approval" : "open",
            source_type: "schedule"
          )
        end
        generated << request if request.previously_new_record?

        if schedule.frequency == "once"
          schedule.update!(status: "completed")
        end
      end

      if schedule.frequency != "once" && due_dates.any?
        next_due_on = schedule.next_due_date(due_dates.last)
        if next_due_on.nil? || (schedule.ends_on.present? && next_due_on > schedule.ends_on)
          schedule.update!(status: "completed")
        else
          schedule.update!(next_due_on: next_due_on)
        end
      end
    end
    generated
  end

  private

  attr_reader :schedule, :through, :manual

  def generated_responsibility
    responsibility = schedule.suggested_responsibility
    return responsibility if MaintenanceRequest::SUGGESTED_RESPONSIBILITIES.include?(responsibility)

    "unknown"
  end
end
