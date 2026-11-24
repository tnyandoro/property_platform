class MaintenanceSchedulePolicy < ApplicationPolicy
  def index? = assigned?
  def show? = assigned?
  def create? = manage?
  def update? = manage?
  def manage? = manager?
  def destroy? = false

  private

  def assigned?
    same_organization? && (
      organization_administrator? ||
      property.property_assignments.where(
        user_id: user.id,
        organization_id: organization_id
      ).where("starts_at <= ?", Time.current)
       .where("ends_at IS NULL OR ends_at >= ?", Time.current)
       .exists?
    )
  end

  def manager?
    assigned? && (
      organization_administrator? ||
      property.property_assignments.where(
        user_id: user.id,
        organization_id: organization_id,
        assignment_type: "manager"
      ).where("starts_at <= ?", Time.current)
       .where("ends_at IS NULL OR ends_at >= ?", Time.current)
       .exists?
    )
  end

  def property
    record.respond_to?(:property) ? record.property : record
  end
end
