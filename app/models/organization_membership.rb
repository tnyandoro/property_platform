class OrganizationMembership < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  ROLES = %w[member administrator].freeze
  STATUSES = %w[active suspended revoked].freeze

  validates :role, inclusion: { in: ROLES }
  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :organization_id }

  scope :active, -> { where(status: "active") }

  def administrator?
    active? && role == "administrator"
  end

  def active?
    status == "active"
  end
end
