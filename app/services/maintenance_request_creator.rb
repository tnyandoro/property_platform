class MaintenanceRequestCreator
  ASSOCIATION_KEYS = MaintenanceRequestAssociationAssigner::ASSOCIATION_KEYS

  def self.call(property:, organization:, actor:, attributes:)
    values = attributes.to_h.symbolize_keys
    request = property.maintenance_requests.new(
      values.except(*ASSOCIATION_KEYS).merge(
        organization: organization,
        reported_by: actor,
        reported_at: Time.current
      )
    )
    MaintenanceRequestAssociationAssigner.call(
      request: request,
      property: property,
      organization: organization,
      attributes: values
    )
    request.save!
    request
  end
end
