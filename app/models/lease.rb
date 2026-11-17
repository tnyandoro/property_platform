class Lease < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :unit
  belongs_to :tenant, class_name: "Party"
  belongs_to :previous_lease, class_name: "Lease", optional: true, inverse_of: :successor_lease
  has_one :successor_lease, class_name: "Lease", foreign_key: :previous_lease_id, inverse_of: :previous_lease
  has_many   :documents, foreign_key: :lease_id, dependent: :destroy
  has_many   :maintenance_requests
  has_many   :maintenance_cost_allocations
  has_many   :renewal_proposals, class_name: "LeaseRenewalProposal", dependent: :restrict_with_error
  has_many   :extension_requests, class_name: "LeaseExtensionRequest", dependent: :restrict_with_error
  has_many   :tenant_invitations, dependent: :restrict_with_error
  has_one_attached :lease_pdf

  STATUSES   = %w[draft active expired terminated cancelled].freeze
  LEASE_TYPES = %w[fixed_term month_to_month periodic].freeze
  MAX_PDF_SIZE = 10 * 1024 * 1024

  validates :status,      inclusion: { in: STATUSES }
  validates :lease_type,  inclusion: { in: LEASE_TYPES }
  validates :start_date, :end_date, :monthly_rent, presence: true
  validate :end_date_is_not_before_start_date
  validate :associations_belong_to_property_and_organization
  validate :lease_pdf_is_a_valid_pdf
  validate :previous_lease_matches_tenancy
  validate :historical_lease_terms_are_immutable, on: :update

  scope :active, -> { where(status: "active") }

  private

  def end_date_is_not_before_start_date
    return if start_date.blank? || end_date.blank? || end_date >= start_date

    errors.add(:end_date, "cannot be before the lease start date")
  end

  def associations_belong_to_property_and_organization
    if property && property.organization_id != organization_id
      errors.add(:property, "must belong to the same organization")
    end

    def previous_lease_matches_tenancy
      return unless previous_lease

      if previous_lease_id == id
        errors.add(:previous_lease, "cannot be itself")
      elsif previous_lease.organization_id != organization_id ||
          previous_lease.property_id != property_id ||
          previous_lease.unit_id != unit_id ||
          previous_lease.tenant_id != tenant_id
        errors.add(:previous_lease, "must belong to the same tenant, unit, property, and organization")
      elsif previous_lease.end_date.present? && start_date.present? && start_date <= previous_lease.end_date
        errors.add(:start_date, "must follow the previous lease end date")
      end
    end

    def historical_lease_terms_are_immutable
      historical_statuses = %w[expired terminated cancelled]
      was_historical = historical_statuses.include?(status_in_database) ||
        (end_date_in_database.present? && end_date_in_database < Date.current)
      will_be_historical = historical_statuses.include?(status)
      return unless was_historical || will_be_historical || successor_lease&.persisted?

      protected_fields = %w[
        property_id unit_id tenant_id start_date end_date lease_type monthly_rent
        rent_currency deposit_amount notice_period_days signed_date terms_summary
      ]
      changed_fields = protected_fields.select { |field| will_save_change_to_attribute?(field) }
      errors.add(:base, "historical lease terms cannot be changed; create a successor lease") if changed_fields.any?
    end
    if unit && (unit.property_id != property_id || unit.organization_id != organization_id)
      errors.add(:unit, "must belong to this property and organization")
    end
    if tenant && tenant.organization_id != organization_id
      errors.add(:tenant, "must belong to the same organization")
    end
  end

  def lease_pdf_is_a_valid_pdf
    return unless lease_pdf.attached?

    blob = lease_pdf.blob
    unless blob.content_type == "application/pdf" && blob.filename.to_s.downcase.end_with?(".pdf")
      errors.add(:lease_pdf, "must be a PDF file")
    end
    errors.add(:lease_pdf, "must be 10 MiB or smaller") if blob.byte_size > MAX_PDF_SIZE
  end
end
