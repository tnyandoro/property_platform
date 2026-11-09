class MaintenanceRequest < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :unit,        optional: true
  belongs_to :room,        optional: true
  belongs_to :reported_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User", optional: true
  has_many   :documents, foreign_key: :maintenance_request_id, dependent: :destroy

  PRIORITIES = %w[low medium high urgent].freeze
  STATUSES   = %w[open acknowledged in_progress resolved closed cancelled].freeze

  validates :title,       presence: true
  validates :priority,    inclusion: { in: PRIORITIES }
  validates :status,      inclusion: { in: STATUSES }
  validates :reported_at, presence: true

  scope :open,   -> { where(status: %w[open acknowledged in_progress]) }
  scope :urgent, -> { where(priority: "urgent") }
end
