class AuditLog < ApplicationRecord
  include TenantScoped

  belongs_to :actor, class_name: "User", optional: true

  ACTIONS = %w[create update destroy lock unlock].freeze

  validates :auditable_type, :auditable_id, :action, :occurred_at, presence: true
  validates :action, inclusion: { in: ACTIONS }

  scope :for_record, ->(record) {
    where(auditable_type: record.class.name, auditable_id: record.id)
  }
end
