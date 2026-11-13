class MaintenanceRequestPolicy < ApplicationPolicy
  def index?   = property_assigned?
  def show?    = property_assigned?
  def create?  = manage?
  def update?  = manage?
  def manage?  = property_manager?
  def assign?  = manage?
  def approve? = manage?
  def verify?  = manage?
  def destroy? = false

  private

  def property
    record.respond_to?(:property) ? record.property : record
  end

  def property_assigned?
    property &&
      property.organization_id == user.organization_id &&
      property.property_assignments.where(
        user_id: user.id,
        organization_id: user.organization_id
      ).where("starts_at <= ?", Time.current)
       .where("ends_at IS NULL OR ends_at >= ?", Time.current)
       .exists?
  end

  def property_manager?
    property_assigned? &&
      property.property_assignments.where(
        user_id: user.id,
        organization_id: user.organization_id,
        assignment_type: "manager"
      ).where("starts_at <= ?", Time.current)
       .where("ends_at IS NULL OR ends_at >= ?", Time.current)
       .exists?
  end
end
