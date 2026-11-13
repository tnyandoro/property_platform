class MaintenanceCostAllocation < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :maintenance_request
  belongs_to :party, optional: true
  belongs_to :approved_by, class_name: "User"

  RESPONSIBLE_PARTIES = %w[owner tenant shared other].freeze

  validates :responsible_party, inclusion: { in: RESPONSIBLE_PARTIES }
  validates :status, inclusion: { in: %w[approved superseded] }
  validates :allocated_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, :rationale, presence: true
  validate :associations_match_request

  private

  def associations_match_request
    return unless maintenance_request

    errors.add(:organization, "must match the maintenance request") if organization_id != maintenance_request.organization_id
    errors.add(:currency, "must match the maintenance request") if currency.present? && currency != maintenance_request.currency
    errors.add(:approved_by, "must belong to the same organization") if approved_by && approved_by.organization_id != organization_id
    if party && party.organization_id != organization_id
      errors.add(:party, "must belong to the same organization")
    end
  end
end
