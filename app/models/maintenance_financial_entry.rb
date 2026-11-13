class MaintenanceFinancialEntry < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :maintenance_request
  belongs_to :party, optional: true
  belongs_to :recorded_by, class_name: "User"

  ENTRY_TYPES = %w[quotation invoice payment].freeze

  validates :entry_type, inclusion: { in: ENTRY_TYPES }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, :occurred_on, presence: true
  validate :associations_match_request

  private

  def associations_match_request
    return unless maintenance_request

    errors.add(:organization, "must match the maintenance request") if organization_id != maintenance_request.organization_id
    errors.add(:currency, "must match the maintenance request") if currency.present? && currency != maintenance_request.currency
    errors.add(:recorded_by, "must belong to the same organization") if recorded_by && recorded_by.organization_id != organization_id
    if party && party.organization_id != organization_id
      errors.add(:party, "must belong to the same organization")
    end
  end
end
