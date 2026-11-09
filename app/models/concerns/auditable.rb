module Auditable
  extend ActiveSupport::Concern

  included do
    after_create_commit  { write_audit("create") }
    after_update_commit  { write_audit("update") }
    after_destroy_commit { write_audit("destroy") }
  end

  private

  def write_audit(action)
    changes_data = action == "update" ? previous_changes.except("updated_at") : {}

    AuditLog.create!(
      organization_id: organization_id,
      actor:           Current.user,
      auditable_type:  self.class.name,
      auditable_id:    id,
      action:          action,
      changes_payload: changes_data,
      occurred_at:     Time.current
    )
  rescue => error
    Rails.logger.error "[Auditable] Failed to write audit log for #{self.class}##{id}: #{error.message}"
  end
end
