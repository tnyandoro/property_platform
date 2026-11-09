class Lease < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :unit
  belongs_to :tenant, class_name: "Party"
  has_many   :documents, foreign_key: :lease_id, dependent: :destroy

  STATUSES   = %w[draft active expired terminated cancelled].freeze
  LEASE_TYPES = %w[fixed_term month_to_month periodic].freeze

  validates :status,      inclusion: { in: STATUSES }
  validates :lease_type,  inclusion: { in: LEASE_TYPES }
  validates :start_date, :monthly_rent, presence: true

  scope :active, -> { where(status: "active") }
end
