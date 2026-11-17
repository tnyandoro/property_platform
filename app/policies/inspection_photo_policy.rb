class InspectionPhotoPolicy < ApplicationPolicy
  def index? = property_assigned?
  def create? = property_assigned? && !record.locked?
  def destroy? = false

  private

  def property_assigned?
    same_organization? && (
      organization_administrator? ||
      record.property.property_assignments.exists?(
        user_id: user.id,
        organization_id: organization_id
      )
    )
  end
end
