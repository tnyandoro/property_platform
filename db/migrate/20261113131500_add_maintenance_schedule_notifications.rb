class AddMaintenanceScheduleNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :maintenance_schedules, :target_completion_on, :date
    add_column :maintenance_schedules, :last_reminder_sent_for, :date
    add_column :maintenance_schedules, :last_overdue_notified_for, :date
    add_column :maintenance_requests, :overdue_notified_for, :date
    add_index :maintenance_schedules, :next_due_on,
      where: "status = 'active'",
      name: "idx_maint_schedules_active_due"
    add_index :maintenance_requests, :target_completion_on,
      where: "target_completion_on IS NOT NULL",
      name: "idx_maint_requests_target_completion"
  end
end
