class InspectionPolicy < ApplicationPolicy
  # Any assigned user may read/create inspections.
  # Only the inspector or a manager may update.
  # Only managers may lock (destroy is not exposed).

  def index?  = property_assigned?
  def show?   = property_assigned?
  def create? = property_assigned?

  def update?
    property_assigned? &&
      (record.inspector_id == user.id || property_manager?)
  end

  def lock?
    property_assigned? && property_manager? && !record.locked?
  end

  private

  def property
    record.property
  end

  def property_assigned?
    same_organization? &&
      property.property_assignments.exists?(
        user_id: user.id,
        organization_id: user.organization_id
      )
  end

  def property_manager?
    property.property_assignments.exists?(
      user_id: user.id,
      organization_id: user.organization_id,
      assignment_type: "manager"
    )
  end
end
