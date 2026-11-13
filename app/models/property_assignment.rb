class PropertyAssignment < ApplicationRecord
  include TenantScoped

  belongs_to :property
  belongs_to :user

  CAPABILITIES = %w[invite_tenants propose_lease_renewals publish_tenant_information].freeze

  validates :assignment_type, :starts_at, presence: true
  validate :capabilities_are_supported
  validate :capability_grants_match_organization

  def has_capability?(capability)
    CAPABILITIES.include?(capability) && capabilities.include?(capability)
  end

  private

  def capabilities_are_supported
    unsupported = Array(capabilities) - CAPABILITIES
    errors.add(:capabilities, "contain unsupported permissions") if unsupported.any?
  end

  def capability_grants_match_organization
    return if Array(capabilities).empty? || user.blank? || property.blank?
    return if user.organization_id == organization_id && property.organization_id == organization_id

    errors.add(:capabilities, "can only be granted to a user assigned within the same organization")
  end
end