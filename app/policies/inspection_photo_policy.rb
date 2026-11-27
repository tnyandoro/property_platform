class InspectionPhotoPolicy < ApplicationPolicy
  def index? = property_assigned?
  def create? = property_assigned? && !inspection.locked?
  def destroy? = false

  private

  def inspection
    record.is_a?(Inspection) ? record : record.inspection
  end

  def property
    inspection&.property
  end

  def property_assigned?
    return false unless user && inspection && property
    return false unless same_organization?

    organization_administrator? || active_assignments.exists?
  end

  def active_assignments
    property.property_assignments
      .where(user_id: user.id, organization_id: organization_id)
      .where("starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
  end
end
