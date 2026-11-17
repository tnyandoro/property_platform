class PartyAccount < ApplicationRecord
  include TenantScoped
  include Auditable

  STATUSES = %w[pending_verification verified revoked].freeze

  belongs_to :user
  belongs_to :party
  belongs_to :verified_by, class_name: "User", optional: true
  belongs_to :revoked_by, class_name: "User", optional: true
  has_one :tenant_profile, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :party_id, uniqueness: { scope: [:organization_id, :user_id] }
  validate :associations_belong_to_organization
  validate :verification_metadata_is_consistent
  validate :revocation_metadata_is_consistent

  scope :verified, -> { where(status: "verified") }

  def verified?
    status == "verified"
  end

  private

  def associations_belong_to_organization
    if party && party.organization_id != organization_id
      errors.add(:party, "must belong to the same organization")
    end

    [verified_by, revoked_by].compact.each do |actor|
      next if actor.member_of?(organization_id) || actor.platform_administrator?

      errors.add(:base, "verifying and revoking users must be active members of the organization")
    end
  end

  def verification_metadata_is_consistent
    if status == "verified" && (verified_at.blank? || verified_by.blank?)
      errors.add(:status, "requires a verifier and verification date")
    elsif status == "pending_verification" && (verified_at.present? || verified_by.present?)
      errors.add(:status, "cannot have verification details while pending")
    elsif verified_at.present? != verified_by.present?
      errors.add(:verified_by, "and verification date must be recorded together")
    end
  end

  def revocation_metadata_is_consistent
    if status == "revoked" && (revoked_at.blank? || revoked_by.blank?)
      errors.add(:status, "requires a revoker and revocation date")
    elsif revoked_at.present? != revoked_by.present?
      errors.add(:revoked_by, "and revocation date must be recorded together")
    elsif status != "revoked" && (revoked_at.present? || revoked_by.present?)
      errors.add(:status, "cannot have revocation details unless revoked")
    end
  end
end
