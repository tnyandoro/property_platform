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
        unless schedule.generation_mode == "reminder_only" && !manual
          generated << schedule.maintenance_requests.create_or_find_by!(occurrence_on: due_on) do |request|
            request.assign_attributes(
              organization: schedule.organization,
              property: schedule.property,
              unit: schedule.unit,
              assigned_to: schedule.assigned_to,
              contractor: schedule.contractor,
              reported_by: schedule.created_by,
              title: schedule.title,
              description: schedule.description,
              category: schedule.category,
              priority: schedule.priority,
              classification: schedule.classification,
              estimated_cost: schedule.estimated_cost,
              currency: schedule.currency,
              reported_at: due_on.in_time_zone,
              status: schedule.generation_mode == "proposed" ? "awaiting_approval" : "open",
              source_type: "schedule"
            )
          end
        end

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
end
