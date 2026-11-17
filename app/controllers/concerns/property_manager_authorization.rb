module PropertyManagerAuthorization
  private

  def authorize_active_property_manager
    return true if Current.membership&.administrator?

    now = Time.current
    manager = property.property_assignments
      .where(organization_id: current_organization.id, user_id: current_user.id, assignment_type: "manager")
      .where("starts_at <= ?", now)
      .where("ends_at IS NULL OR ends_at >= ?", now)
      .exists?

    return true if manager

    render json: { error: "Only an active property manager can manage property records." }, status: :forbidden
    false
  end
end
