class MaintenanceMailer < ApplicationMailer
  def schedule_notification(schedule:, recipient:, due_on:, overdue:)
    subject = overdue ? "Overdue maintenance: #{schedule.title}" : "Upcoming maintenance: #{schedule.title}"
    body = if overdue
      "#{schedule.title} was due on #{due_on}. Review the maintenance plan and take any required action."
    else
      "#{schedule.title} is due on #{due_on}. Review the maintenance plan and prepare the work."
    end
    mail(to: recipient.email, subject: subject, body: body)
  end

  def work_order_overdue(request:, recipient:)
    mail(
      to: recipient.email,
      subject: "Overdue maintenance work: #{request.title}",
      body: "#{request.title} passed its target completion date of #{request.target_completion_on}. Review the work order."
    )
  end
end
