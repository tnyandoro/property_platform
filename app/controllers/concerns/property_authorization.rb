module PropertyAuthorization
  extend ActiveSupport::Concern

  private

  def accessible_properties
    current_organization.properties
      .joins(:property_assignments)
      .where(
        property_assignments: {
          organization_id: current_organization.id,
          user_id: current_user.id
        }
      )
      .where("property_assignments.starts_at <= ?", Time.current)
      .where("property_assignments.ends_at IS NULL OR property_assignments.ends_at >= ?", Time.current)
      .distinct
  end

  def accessible_property
    accessible_properties.find(params[:id])
  end

  def accessible_nested_property
    accessible_properties.find(params[:property_id])
  end
end