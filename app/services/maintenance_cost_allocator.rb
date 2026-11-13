class MaintenanceCostAllocator
  class InvalidAllocation < StandardError; end

  def self.call(request:, allocations:, actor:, rationale:)
    new(request, allocations, actor, rationale).call
  end

  def initialize(request, allocations, actor, rationale)
    @request = request
    @allocations = allocations
    @actor = actor
    @rationale = rationale.to_s.strip
  end

  def call
    raise InvalidAllocation, "At least one allocation is required." unless allocations.is_a?(Array) && allocations.any?
    raise InvalidAllocation, "Rationale is required." if rationale.blank?

    request.with_lock do
      raise InvalidAllocation, "An approved cost is required before allocating responsibility." if request.approved_cost.nil?
      if request.responsibility_status == "approved"
        raise InvalidAllocation, "Cost responsibility is already approved. Dispute it before recording a revised allocation."
      end

      normalized = allocations.map { |attributes| normalize(attributes) }
      amounts = normalized.map { |attributes| decimal_amount(attributes[:allocated_amount]) }
      unless amounts.all? { |amount| amount&.finite? && amount >= 0 }
        raise InvalidAllocation, "Allocation amounts must be valid non-negative amounts."
      end
      unless normalized.all? { |attributes| (attributes[:currency].presence || request.currency) == request.currency }
        raise InvalidAllocation, "Allocation currencies must match the work order currency."
      end
      unless amounts.sum == request.approved_cost
        raise InvalidAllocation, "Allocations must equal the approved cost."
      end
      validate_percentages!(normalized)

      request.cost_allocations.where(status: "approved").each { |allocation| allocation.update!(status: "superseded") } if request.responsibility_status == "disputed"
      records = normalized.map { |attributes| create_allocation!(attributes) }
      request.update!(
        responsibility_status: "approved",
        responsibility_notes: rationale,
        responsibility_reviewed_by: actor,
        responsibility_reviewed_at: Time.current
      )
      records
    end
  end

  private

  attr_reader :request, :allocations, :actor, :rationale

  def normalize(attributes)
    attributes.to_h.symbolize_keys
  end

  def create_allocation!(attributes)
    organization = request.organization
    party = organization.parties.find(attributes[:party_id]) if attributes[:party_id].present?
    lease = request.property.leases.find(attributes[:lease_id]) if attributes[:lease_id].present?
    ownership = request.property.property_ownerships.find(attributes[:property_ownership_id]) if attributes[:property_ownership_id].present?

    if lease && request.lease_id.present? && lease.id != request.lease_id
      raise InvalidAllocation, "Lease must match the lease linked to the work order."
    end
    if attributes[:responsible_party] == "tenant"
      raise InvalidAllocation, "A tenant allocation must identify the tenant party." unless party

      lease ||= request.lease if request.lease_id.present?
      if lease && lease.tenant_id != party.id
        raise InvalidAllocation, "Tenant party must match the selected lease."
      end
    end

    request.cost_allocations.create!(
      organization: organization,
      responsible_party: attributes.fetch(:responsible_party),
      allocated_amount: attributes.fetch(:allocated_amount),
      allocation_percentage: attributes[:allocation_percentage],
      currency: attributes[:currency].presence || request.currency,
      rationale: rationale,
      party: party,
      lease: lease,
      property_ownership: ownership,
      approved_by: actor
    )
  end

  def validate_percentages!(normalized)
    percentages = normalized.map { |attributes| attributes[:allocation_percentage] }
    return if percentages.all?(&:blank?)
    raise InvalidAllocation, "All allocations must specify a percentage when any percentage is supplied." if percentages.any?(&:blank?)

    values = percentages.map { |value| decimal_amount(value) }
    unless values.all? { |value| value&.finite? && value >= 0 && value <= 100 } && values.sum == 100
      raise InvalidAllocation, "Allocation percentages must be valid and total 100."
    end
  end

  def decimal_amount(value)
    BigDecimal(value.to_s, exception: false)
  end
end
