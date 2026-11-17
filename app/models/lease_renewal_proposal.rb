class LeaseRenewalProposal < ApplicationRecord
  include TenantScoped
  include Auditable

  STATUSES = %w[draft offered accepted rejected expired withdrawn].freeze

  belongs_to :lease
  belongs_to :created_by, class_name: "User"
  belongs_to :responded_by, class_name: "User", optional: true
  belongs_to :resulting_lease, class_name: "Lease", optional: true
  belongs_to :document, optional: true

  before_validation :assign_version_number, on: :create

  validates :version_number, numericality: { only_integer: true, greater_than: 0 }
  validates :proposed_start_date, :proposed_end_date, :proposed_monthly_rent, :rent_currency, presence: true
  validates :proposed_monthly_rent, numericality: { greater_than_or_equal_to: 0 }
  validates :rent_currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :status, inclusion: { in: STATUSES }
  validate :associations_belong_to_lease
  validate :creator_is_authorized
  validate :proposed_dates_follow_existing_lease
  validate :response_metadata_matches_status
  validate :resulting_lease_matches_proposal
  validate :shared_document_matches_proposal
  validate :offer_has_a_future_expiry, if: :offering?

  private

  def assign_version_number
    return if version_number.present? || lease_id.blank?

    self.version_number = self.class.where(lease_id: lease_id).maximum(:version_number).to_i + 1
  end

  def associations_belong_to_lease
    return unless lease

    errors.add(:lease, "must belong to the same organization") if lease.organization_id != organization_id
    if !%w[active expired].include?(lease.status)
      errors.add(:lease, "must be active or expired to propose a renewal")
    end
    [created_by, responded_by].compact.each do |user|
      errors.add(:base, "users must belong to the same organization") if user.organization_id != organization_id
    end
  end

  def creator_is_authorized
    return unless lease && created_by

    unless created_by.authorized_for_property?(lease.property, "propose_lease_renewals")
      errors.add(:created_by, "is not authorized to propose a renewal for this property")
    end
  end

  def proposed_dates_follow_existing_lease
    return unless lease && proposed_start_date && proposed_end_date

    errors.add(:proposed_end_date, "cannot be before the proposed start date") if proposed_end_date < proposed_start_date
    if lease.end_date.present? && proposed_start_date <= lease.end_date
      errors.add(:proposed_start_date, "must follow the existing lease end date")
    end
  end

  def response_metadata_matches_status
    response_required = %w[accepted rejected withdrawn].include?(status)
    if response_required && (responded_at.blank? || responded_by.blank?)
      errors.add(:responded_by, "and response date are required for this decision")
    elsif %w[accepted rejected].include?(status) && expires_at.blank?
      errors.add(:expires_at, "is required before the tenant can respond")
    elsif status == "draft" && (responded_at.present? || responded_by.present? || resulting_lease.present?)
      errors.add(:status, "cannot have response details while in draft")
    elsif status == "offered" && (responded_at.present? || responded_by.present? || resulting_lease.present?)
      errors.add(:status, "cannot have response details before the tenant responds")
    elsif status == "accepted" && resulting_lease.blank?
      errors.add(:resulting_lease, "is required when a renewal is accepted")
    elsif status != "accepted" && resulting_lease.present?
      errors.add(:resulting_lease, "is only allowed for an accepted renewal")
    end

    if %w[accepted rejected].include?(status) && !tenant_is_respondent?
      errors.add(:responded_by, "must be the verified tenant for this lease")
    end
    if %w[accepted rejected].include?(status) && expires_at.present? &&
       responded_at.present? && responded_at > expires_at
      errors.add(:responded_at, "cannot be after the offer expiry")
    end
    if status == "expired" && (responded_at.blank? || expires_at.blank? || responded_at < expires_at)
      errors.add(:responded_at, "must record expiration at or after the offer expiry")
    end
    if status == "expired" && responded_by.present?
      errors.add(:responded_by, "must be blank when the system expires an offer")
    end
    if status == "withdrawn" && responded_by != created_by
      errors.add(:responded_by, "must be the proposer when withdrawing")
    end
  end

  def tenant_is_respondent?
    return false unless lease && responded_by

    responded_by.party_accounts
      .verified
      .joins(:tenant_profile)
      .where(organization_id: organization_id, party_id: lease.tenant_id)
      .exists?
  end

  def resulting_lease_matches_proposal
    return unless resulting_lease

    matches = resulting_lease.organization_id == organization_id &&
      resulting_lease.previous_lease_id == lease_id &&
      resulting_lease.tenant_id == lease&.tenant_id &&
      resulting_lease.property_id == lease&.property_id &&
      resulting_lease.unit_id == lease&.unit_id &&
      resulting_lease.start_date == proposed_start_date &&
      resulting_lease.end_date == proposed_end_date &&
      resulting_lease.monthly_rent == proposed_monthly_rent &&
      resulting_lease.rent_currency == rent_currency
    errors.add(:resulting_lease, "must preserve the accepted proposal terms and lease history") unless matches
  end

  def shared_document_matches_proposal
    return unless document

    unless document.organization_id == organization_id && document.lease_id == lease_id
      errors.add(:document, "must belong to this lease and organization")
    end
    if %w[offered accepted].include?(status) && document.visibility != "tenant_visible"
      errors.add(:document, "must be tenant-visible before the proposal is offered")
    end
  end

  def offer_has_a_future_expiry
    return if expires_at.present? && expires_at > Time.current

    errors.add(:expires_at, "must be in the future when offering a renewal")
  end

  def offering?
    status == "offered" && (new_record? || will_save_change_to_status?)
  end
end
