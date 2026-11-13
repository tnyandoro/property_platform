class User < ApplicationRecord
  include TenantScoped

  has_secure_password

  has_many :property_assignments
  has_many :properties, through: :property_assignments
  has_many :party_accounts, dependent: :restrict_with_error
  has_many :tenant_profiles, through: :party_accounts
  has_many :platform_administrator_grants, dependent: :restrict_with_error

  ORGANIZATION_ROLES = %w[member administrator].freeze

  validates :email, presence: true, uniqueness: { scope: :organization_id }
  validates :first_name, :last_name, presence: true
  validates :organization_role, inclusion: { in: ORGANIZATION_ROLES }, if: -> { has_attribute?(:organization_role) }

  normalizes :email, with: ->(email) { email.strip.downcase }

  def platform_administrator?
    platform_administrator_grants.active.exists?
  end

  def authorized_for_property?(property, capability)
    return false unless property
    platform_admin = platform_administrator?
    return false unless platform_admin || property.organization_id == organization_id
    return true if platform_admin || organization_role == "administrator"

    verified_party_ids = party_accounts.verified.pluck(:party_id)
    if PropertyOwnership.active_on(Date.current)
        .where(
          organization_id: property.organization_id,
          property_id: property.id,
          party_id: verified_party_ids,
          verification_status: "verified"
        )
        .exists?
      return true
    end

    property_assignments
      .where(property_id: property.id, organization_id: property.organization_id)
      .where("starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
      .any? { |assignment| assignment.has_capability?(capability) }
  end
end