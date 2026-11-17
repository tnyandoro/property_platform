class User < ApplicationRecord
  include TenantScoped

  has_secure_password

  has_many :organization_memberships, dependent: :restrict_with_error
  has_many :member_organizations, through: :organization_memberships, source: :organization
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

  after_create :create_initial_organization_membership

  def membership_for(organization)
    organization_id = organization.respond_to?(:id) ? organization.id : organization
    organization_memberships.active.find_by(organization_id: organization_id)
  end

  def member_of?(organization)
    membership_for(organization).present?
  end

  def platform_administrator?
    platform_administrator_grants.active.exists?
  end

  def authorized_for_property?(property, capability)
    return false unless property
    platform_admin = platform_administrator?
    membership = membership_for(property.organization_id)
    return true if platform_admin || membership&.administrator?

    # A verified owner may access their property without being an employee
    # or member of the organisation that manages it.
    verified_party_ids = party_accounts.verified
      .where(organization_id: property.organization_id)
      .pluck(:party_id)
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

    return false unless membership

    property_assignments
      .where(property_id: property.id, organization_id: property.organization_id)
      .where("starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
      .any? { |assignment| assignment.has_capability?(capability) }
  end

  private

  def create_initial_organization_membership
    organization_memberships.create!(
      organization: organization,
      role: organization_role.presence || "member",
      status: "active"
    )
  end
end
