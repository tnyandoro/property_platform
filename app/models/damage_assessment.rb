class DamageAssessment < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :inspection,      optional: true
  belongs_to :inspection_item, optional: true
  belongs_to :assessed_by,     class_name: "User"
  has_many   :documents, foreign_key: :damage_assessment_id, dependent: :destroy
  has_many   :maintenance_requests, foreign_key: :source_damage_assessment_id

  SEVERITIES       = %w[minor moderate severe critical].freeze
  RESPONSIBILITIES = %w[landlord tenant shared unknown].freeze
  STATUSES         = %w[open under_review agreed disputed resolved written_off].freeze

  validates :severity,       inclusion: { in: SEVERITIES }
  validates :responsibility, inclusion: { in: RESPONSIBILITIES }
  validates :status,         inclusion: { in: STATUSES }
  validates :description, :assessed_on, presence: true
end
