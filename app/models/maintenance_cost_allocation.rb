class MaintenanceCostAllocation < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :maintenance_request
  belongs_to :party, optional: true
  belongs_to :lease, optional: true
  belongs_to :property_ownership, optional: true
  belongs_to :approved_by, class_name: "User"

  RESPONSIBLE_PARTIES = %w[owner tenant shared other organization third_party].freeze

  validates :responsible_party, inclusion: { in: RESPONSIBLE_PARTIES }
  validates :status, inclusion: { in: %w[approved superseded] }
  validates :allocated_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :allocation_percentage,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
    allow_nil: true
  validates :currency, :rationale, presence: true
  validate :associations_match_request
  validate :approved_allocation_reconciles
  before_validation :set_approved_at

  private

  def associations_match_request
    return unless maintenance_request

    errors.add(:organization, "must match the maintenance request") if organization_id != maintenance_request.organization_id
    errors.add(:currency, "must match the maintenance request") if currency.present? && currency != maintenance_request.currency
    errors.add(:approved_by, "must belong to the same organization") if approved_by && approved_by.organization_id != organization_id
    if party && party.organization_id != organization_id
      errors.add(:party, "must belong to the same organization")
    end
    if lease && (lease.organization_id != organization_id || lease.property_id != maintenance_request.property_id)
      errors.add(:lease, "must belong to the same property and organization")
    end
    if lease && responsible_party != "tenant"
      errors.add(:lease, "can only be linked to a tenant allocation")
    end
    if lease && party && lease.tenant_id != party.id
      errors.add(:party, "must be the tenant associated with the selected lease")
    end
    if property_ownership &&
       (property_ownership.organization_id != organization_id ||
        property_ownership.property_id != maintenance_request.property_id)
      errors.add(:property_ownership, "must belong to the maintenance request property and organization")
    end
    if property_ownership && responsible_party != "owner"
      errors.add(:property_ownership, "can only be linked to an owner allocation")
    end
    if property_ownership && party && property_ownership.party_id != party.id
      errors.add(:party, "must match the selected property ownership")
    end
  end

  def approved_allocation_reconciles
    return unless status == "approved" && maintenance_request&.responsibility_status == "approved"
    return if maintenance_request.approved_cost.nil?

    other_amounts = maintenance_request.cost_allocations
      .where(status: "approved")
      .where.not(id: id)
      .sum(:allocated_amount)
    unless other_amounts + allocated_amount.to_d == maintenance_request.approved_cost
      errors.add(:allocated_amount, "must reconcile to the approved maintenance amount")
    end
  end

  def set_approved_at
    self.approved_at ||= Time.current if status == "approved" && approved_by
  end
end
