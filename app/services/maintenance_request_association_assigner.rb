class MaintenanceRequestAssociationAssigner
  ASSOCIATION_KEYS = %i[
    unit_id room_id lease_id assigned_to_id contractor_id source_inspection_id
    source_inspection_item_id source_damage_assessment_id
  ].freeze

  def self.call(request:, property:, organization:, attributes:)
    values = attributes.to_h.symbolize_keys

    request.unit = property.units.find(values[:unit_id]) if values.key?(:unit_id) && values[:unit_id].present?
    request.unit = nil if values.key?(:unit_id) && values[:unit_id].blank?
    request.room = property.rooms.find(values[:room_id]) if values.key?(:room_id) && values[:room_id].present?
    request.room = nil if values.key?(:room_id) && values[:room_id].blank?
    request.lease = property.leases.find(values[:lease_id]) if values.key?(:lease_id) && values[:lease_id].present?
    request.lease = nil if values.key?(:lease_id) && values[:lease_id].blank?
    request.assigned_to = organization.users.find(values[:assigned_to_id]) if values.key?(:assigned_to_id) && values[:assigned_to_id].present?
    request.assigned_to = nil if values.key?(:assigned_to_id) && values[:assigned_to_id].blank?
    request.contractor = organization.parties.find(values[:contractor_id]) if values.key?(:contractor_id) && values[:contractor_id].present?
    request.contractor = nil if values.key?(:contractor_id) && values[:contractor_id].blank?

    request.unit ||= request.room.unit if request.room
    request.unit ||= request.lease.unit if request.lease

    request.source_inspection = property.inspections.find(values[:source_inspection_id]) if values.key?(:source_inspection_id) && values[:source_inspection_id].present?
    request.source_inspection = nil if values.key?(:source_inspection_id) && values[:source_inspection_id].blank?
    request.source_type = "inspection" if request.source_inspection

    if values[:source_inspection_item_id].present?
      request.source_inspection_item = InspectionItem.joins(:inspection)
        .where(organization_id: organization.id, inspections: { property_id: property.id })
        .find(values[:source_inspection_item_id])
      request.source_inspection ||= request.source_inspection_item.inspection
      request.source_type = "inspection"
    elsif values.key?(:source_inspection_item_id)
      request.source_inspection_item = nil
    end

    if values.key?(:source_damage_assessment_id)
      request.source_damage_assessment = values[:source_damage_assessment_id].present? ?
        property.damage_assessments.find(values[:source_damage_assessment_id]) : nil
      request.source_type = "damage_assessment" if request.source_damage_assessment
    end

    request
  end
end
