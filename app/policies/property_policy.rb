class PropertyPolicy < ApplicationPolicy
  # Any user in the same org with an active assignment may read.
  # Only managers may create/update/destroy.

  def index?  = true   # list is scoped by accessible_properties before policy runs

  def show?   = assigned?

  def create? = true   # org membership enforced in controller; assignment created on create

  def update? = manager?

  def destroy? = manager?

  private

  def assigned?
    same_organization? &&
      record.property_assignments.exists?(
        user_id: user.id,
        organization_id: user.organization_id
      )
  end

  def manager?
    same_organization? &&
      record.property_assignments.exists?(
        user_id: user.id,
        organization_id: user.organization_id,
        assignment_type: "manager"
      )
  end
end
