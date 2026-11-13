class Lease < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :unit
  belongs_to :tenant, class_name: "Party"
  has_many   :documents, foreign_key: :lease_id, dependent: :destroy
  has_many   :maintenance_requests
  has_many   :maintenance_cost_allocations
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
