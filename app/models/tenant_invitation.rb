class TenantInvitation < ApplicationRecord
  include TenantScoped
  include Auditable

  STATUSES = %w[pending accepted revoked expired].freeze

  belongs_to :tenant_party, class_name: "Party"
  belongs_to :property
  belongs_to :lease
  belongs_to :invited_by, class_name: "User"
  belongs_to :accepted_user, class_name: "User", optional: true
  belongs_to :revoked_by, class_name: "User", optional: true

  scope :pending, -> { where(status: "pending") }

  before_validation :normalize_target_email

  validates :target_email, :token_digest, :expires_at, presence: true
  validates :token_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :target_email,
    uniqueness: { scope: [:organization_id, :lease_id], conditions: -> { where(status: "pending") } },
    if: -> { status == "pending" }
  validates :status, inclusion: { in: STATUSES }
  validate :scope_matches_lease
  validate :inviter_is_authorized
  validate :acceptance_metadata_is_consistent
  validate :revocation_metadata_is_consistent
  validate :expiry_metadata_is_consistent
  validate :new_invitation_has_future_expiry, on: :create

  def valid_for_activation?(at: Time.current)
    status == "pending" && expires_at.present? && expires_at > at
  end

  private

  def normalize_target_email
    self.target_email = target_email.strip.downcase if target_email.is_a?(String)
  end

  def scope_matches_lease
    return unless lease

    errors.add(:lease, "must belong to the same organization") if lease.organization_id != organization_id
    errors.add(:tenant_party, "must be the tenant on this lease") if lease.tenant_id != tenant_party_id
    errors.add(:property, "must be the property on this lease") if lease.property_id != property_id
    errors.add(:tenant_party, "must belong to the same organization") if tenant_party && tenant_party.organization_id != organization_id
    errors.add(:property, "must belong to the same organization") if property && property.organization_id != organization_id
    if lease.status != "active" || (lease.end_date.present? && lease.end_date < Date.current)
      errors.add(:lease, "must be an eligible active lease")
    end
  end

  def inviter_is_authorized
    if invited_by && invited_by.organization_id != organization_id && !invited_by.platform_administrator?
      errors.add(:invited_by, "must belong to the same organization")
    end
    if property && invited_by && !invited_by.authorized_for_property?(property, "invite_tenants")
      errors.add(:invited_by, "is not authorized to invite tenants for this property")
    end
    if status == "revoked" && revoked_by && property &&
       !revoked_by.authorized_for_property?(property, "invite_tenants")
      errors.add(:revoked_by, "is not authorized to revoke invitations for this property")
    end
  end

  def acceptance_metadata_is_consistent
    if status == "accepted"
      errors.add(:accepted_user, "must match the invitation email and organization") unless accepted_user &&
        accepted_user.organization_id == organization_id &&
        accepted_user.email == target_email &&
        accepted_user.email_verified_at.present?
      unless accepted_user&.party_accounts&.verified&.joins(:tenant_profile)&.exists?(
        organization_id: organization_id,
        party_id: tenant_party_id
      )
        errors.add(:accepted_user, "must have a verified profile for the invited tenant")
      end
      errors.add(:accepted_at, "is required for an accepted invitation") if accepted_at.blank?
    elsif accepted_at.present? || accepted_user.present?
      errors.add(:status, "cannot have acceptance details unless accepted")
    end
  end

  def revocation_metadata_is_consistent
    if status == "revoked"
      errors.add(:revoked_by, "is required for a revoked invitation") if revoked_by.blank?
      errors.add(:revoked_at, "is required for a revoked invitation") if revoked_at.blank?
    elsif revoked_at.present? || revoked_by.present?
      errors.add(:status, "cannot have revocation details unless revoked")
    end
  end

  def expiry_metadata_is_consistent
    if status == "expired"
      errors.add(:expired_at, "is required for an expired invitation") if expired_at.blank?
    elsif expired_at.present?
      errors.add(:status, "cannot have expiry details unless expired")
    end
  end

  def new_invitation_has_future_expiry
    errors.add(:expires_at, "must be in the future") if expires_at.present? && expires_at <= Time.current
  end
end
