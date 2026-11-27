class InspectionPolicy < ApplicationPolicy
  # Any actively assigned user may read/create inspections.
  # Only the inspector or an active manager may update.
  # Only active managers may lock.

  def index? = property_assigned?
  def show? = property_assigned?
  def create? = property_assigned?

  def update?
    property_assigned? &&
      (record.inspector_id == user&.id || property_manager?)
  end

  def lock?
    property_assigned? && property_manager? && !record.locked?
  end

  private

  def property
    record.respond_to?(:property) ? record.property : record
  end

  def property_assigned?
    return false unless user && property
    return false unless same_organization?

    organization_administrator? || active_assignments.exists?
  end

  def property_manager?
    return false unless user && property
    return false unless same_organization?

    organization_administrator? ||
      active_assignments.where(assignment_type: "manager").exists?
  end

  def active_assignments
    property.property_assignments
      .where(user_id: user.id, organization_id: organization_id)
      .where("starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
  end
end
