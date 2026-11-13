class MaintenanceRequestWorkflow
  class InvalidTransition < StandardError; end
  class InvalidInput < StandardError; end

  def self.call(request:, action:, actor:, attributes: {})
    new(request, action, actor, attributes).call
  end

  def initialize(request, action, actor, attributes)
    @request = request
    @action = action.to_sym
    @actor = actor
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
    request.with_lock do
      case action
      when :acknowledge
        transition!(%w[open], "acknowledged", acknowledged_at: Time.current)
      when :submit_for_approval
        transition!(%w[open acknowledged], "awaiting_approval")
      when :approve
        approve!
      when :reject
        reject!
      when :schedule
        schedule!
      when :start
        transition!(%w[scheduled approved acknowledged], "in_progress", actual_started_at: Time.current)
      when :complete
        complete!
      when :verify
        verify!
      when :close
        close!
      when :cancel
        cancel!
      when :dispute_responsibility
        dispute_responsibility!
      when :assign
        assign!
      else
        raise ArgumentError, "Unknown maintenance workflow action: #{action}"
      end
    end
    request
  end

  private

  attr_reader :request, :action, :actor, :attributes

  def transition!(allowed_statuses, status, extra_attributes = {})
    raise InvalidTransition unless allowed_statuses.include?(request.status)

    request.update!(extra_attributes.merge(status: status))
  end

  def approve!
    amount = decimal_amount(attributes[:approved_cost])
    raise InvalidInput, "approved_cost must be a non-negative amount." unless amount&.finite? && amount >= 0
    raise InvalidTransition unless request.status == "awaiting_approval"

    request.update!(
      status: "approved",
      approved_cost: amount,
      approval_notes: attributes[:comments],
      approved_by: actor,
      approved_at: Time.current
    )
  end

  def reject!
    reason = attributes[:reason].to_s.strip
    raise InvalidInput, "reason is required." if reason.blank?
    raise InvalidTransition unless request.status == "awaiting_approval"

    request.update!(
      status: "rejected",
      rejection_reason: reason,
      rejected_by: actor,
      rejected_at: Time.current
    )
  end

  def schedule!
    scheduled_on = attributes[:scheduled_on]
    raise InvalidInput, "scheduled_on is required." if scheduled_on.blank?
    raise InvalidTransition unless %w[approved acknowledged open].include?(request.status)

    request.update!(
      scheduled_on: scheduled_on,
      target_completion_on: attributes[:target_completion_on],
      status: "scheduled"
    )
  end

  def complete!
    raise InvalidTransition unless request.status == "in_progress"

    updates = {
      status: "resolved",
      resolved_at: Time.current
    }
    if attributes.key?(:actual_cost)
      cost = attributes[:actual_cost].present? ? decimal_amount(attributes[:actual_cost]) : nil
      if attributes[:actual_cost].present? && (!cost || !cost.finite? || cost.negative?)
        raise InvalidInput, "actual_cost must be a non-negative amount."
      end

      updates[:actual_cost] = cost
    end
    updates[:resolution_notes] = attributes[:resolution_notes] if attributes.key?(:resolution_notes)
    request.update!(updates)
  end

  def verify!
    raise InvalidTransition unless request.status == "resolved"

    request.update!(verified_by: actor, verified_at: Time.current)
  end

  def close!
    raise InvalidTransition unless request.status == "resolved"

    request.update!(
      status: "closed",
      closed_at: Time.current,
      closed_by: actor,
      verified_by: request.verified_by || actor,
      verified_at: request.verified_at || Time.current
    )
  end

  def cancel!
    reason = attributes[:reason].to_s.strip
    raise InvalidInput, "reason is required." if reason.blank?
    raise InvalidTransition if %w[closed cancelled].include?(request.status)

    request.update!(status: "cancelled", cancellation_reason: reason)
  end

  def dispute_responsibility!
    rationale = attributes[:rationale].to_s.strip
    raise InvalidInput, "rationale is required." if rationale.blank?

    request.update!(
      responsibility_status: "disputed",
      responsibility_notes: rationale,
      responsibility_reviewed_by: actor,
      responsibility_reviewed_at: Time.current
    )
  end

  def assign!
    raise InvalidInput, "Provide an assignee or contractor." unless attributes.key?(:assigned_to_id) || attributes.key?(:contractor_id)

    updates = {}
    if attributes.key?(:assigned_to_id)
      updates[:assigned_to] = attributes[:assigned_to_id].present? ?
        request.organization.users.find(attributes[:assigned_to_id]) : nil
    end
    if attributes.key?(:contractor_id)
      updates[:contractor] = attributes[:contractor_id].present? ?
        request.organization.parties.find(attributes[:contractor_id]) : nil
    end
    request.update!(updates)
  end

  def decimal_amount(value)
    BigDecimal(value.to_s, exception: false)
  end
end
