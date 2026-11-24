class PropertyPolicy < ApplicationPolicy
  # Any assigned user may read; organization administrators may manage all properties.

  def index? = true

  def show? = assigned?

  def create? = same_organization?

  def update? = manager?

  def destroy? = manager?

  private

  def assigned?
    same_organization? && (
      organization_administrator? ||
      record.property_assignments.exists?(
        user_id: user.id,
        organization_id: organization_id
      )
    )
  end

  def manager?
    same_organization? && (
      organization_administrator? ||
      record.property_assignments.exists?(
        user_id: user.id,
        organization_id: organization_id,
        assignment_type: "manager"
      )
    )
  end
end
