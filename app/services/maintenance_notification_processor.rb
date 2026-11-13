class MaintenanceNotificationProcessor
  def self.call(today: Date.current)
    new(today: today).call
  end

  def initialize(today:)
    @today = today
  end

  def call
    MaintenanceSchedule.where(status: "active").includes(:assigned_to, :created_by).find_each do |schedule|
      notify_schedule(schedule)
    end
    notify_overdue_work_orders
  end

  private

  attr_reader :today

  def notify_schedule(schedule)
    schedule.with_lock do
      next unless schedule.status == "active"

      due_on = schedule.next_due_on
      if due_on < today
        next if schedule.last_overdue_notified_for == due_on

        recipients = schedule_recipients(schedule)
        next if recipients.empty?

        recipients.each do |recipient|
          MaintenanceMailer.schedule_notification(
            schedule: schedule,
            recipient: recipient,
            due_on: due_on,
            overdue: true
          ).deliver_later
        end
        schedule.update!(last_overdue_notified_for: due_on)
      elsif due_on - schedule.reminder_days <= today &&
          schedule.last_reminder_sent_for != due_on
        recipients = schedule_recipients(schedule)
        next if recipients.empty?

        recipients.each do |recipient|
          MaintenanceMailer.schedule_notification(
            schedule: schedule,
            recipient: recipient,
            due_on: due_on,
            overdue: false
          ).deliver_later
        end
        schedule.update!(last_reminder_sent_for: due_on)
      end
    end
  end

  def notify_overdue_work_orders
    MaintenanceRequest.where("target_completion_on < ?", today)
      .where.not(status: %w[resolved closed rejected cancelled])
      .where("overdue_notified_for IS NULL OR overdue_notified_for <> target_completion_on")
      .includes(:assigned_to, :reported_by)
      .find_each do |request|
        request.with_lock do
          next if request.target_completion_on.blank? ||
            request.target_completion_on >= today ||
            request.overdue_notified_for == request.target_completion_on

          recipients = [request.assigned_to, request.reported_by].compact.uniq(&:id)
          next if recipients.empty?

          recipients.each do |recipient|
            MaintenanceMailer.work_order_overdue(request: request, recipient: recipient).deliver_later
          end
          request.update!(overdue_notified_for: request.target_completion_on)
        end
      end
  end

  def schedule_recipients(schedule)
    [schedule.assigned_to, schedule.created_by].compact.uniq(&:id)
  end
end
