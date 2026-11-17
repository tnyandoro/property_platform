class LeaseExtensionRequest < ApplicationRecord
  include TenantScoped
  include Auditable

  STATUSES = %w[pending proposal_created rejected withdrawn closed].freeze

  belongs_to :lease
  belongs_to :tenant_profile
  belongs_to :requested_by, class_name: "User"
  belongs_to :responded_by, class_name: "User", optional: true
  belongs_to :lease_renewal_proposal, optional: true

  validates :status, inclusion: { in: STATUSES }
  validate :requester_is_the_lease_tenant
  validate :response_metadata_matches_status
  validate :linked_proposal_matches_lease
  validate :requested_end_date_follows_lease

  private

  def requester_is_the_lease_tenant
    return unless lease && tenant_profile && requested_by

    errors.add(:lease, "must belong to the same organization") if lease.organization_id != organization_id
    errors.add(:tenant_profile, "must belong to the same organization") if tenant_profile.organization_id != organization_id
    errors.add(:requested_by, "must be the tenant profile user") if tenant_profile.user_id != requested_by_id
    errors.add(:tenant_profile, "must represent the tenant on this lease") if tenant_profile.party_id != lease.tenant_id
    errors.add(:tenant_profile, "must have a verified account") unless tenant_profile.party_account.verified?
    errors.add(:requested_by, "must belong to the same organization") if requested_by.organization_id != organization_id
    if lease.status != "active" || (lease.end_date.present? && lease.end_date < Date.current)
      errors.add(:lease, "must be an eligible active lease")
    end
  end

  def response_metadata_matches_status
    if status == "pending"
      if responded_at.present? || responded_by.present?
        errors.add(:status, "cannot have response details while pending")
      end
      return
    end

    if responded_at.blank? || responded_by.blank?
      errors.add(:responded_by, "and response date are required after the request is reviewed")
    elsif responded_by.organization_id != organization_id
      errors.add(:responded_by, "must belong to the same organization")
    elsif status == "withdrawn"
      errors.add(:responded_by, "must be the tenant who submitted the request") if responded_by_id != requested_by_id
    elsif lease && !responded_by.authorized_for_property?(lease.property, "propose_lease_renewals")
      errors.add(:responded_by, "is not authorized to review extension requests for this property")
    end
    if status == "proposal_created" && lease_renewal_proposal.blank?
      errors.add(:lease_renewal_proposal, "is required when a renewal proposal is created")
    end
  end

  def linked_proposal_matches_lease
    return unless lease_renewal_proposal

    if lease_renewal_proposal.organization_id != organization_id ||
        lease_renewal_proposal.lease_id != lease_id
      errors.add(:lease_renewal_proposal, "must be for this lease and organization")
    end
    if status == "proposal_created" && lease_renewal_proposal.status != "offered"
      errors.add(:lease_renewal_proposal, "must be an offered renewal proposal")
    end
  end

  def requested_end_date_follows_lease
    return if requested_end_date.blank? || lease&.end_date.blank? || requested_end_date > lease.end_date

    errors.add(:requested_end_date, "must follow the existing lease end date")
  end
end
