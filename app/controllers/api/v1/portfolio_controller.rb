module Api
  module V1
    class PortfolioController < PropertyResourcesController
      include OwnershipSerialization
      include LeaseSerialization

      def show
        render json: {
          property:    property_payload,
          buildings:   property.buildings.map { |building| building_payload(building) },
          units:       property.units.map { |unit| unit_payload(unit) },
          rooms:       property.rooms.map { |room| room_payload(room) },
          items:       property.property_items.map { |item| item_payload(item) },
          ownership:   property.property_ownerships
            .includes(:party, :verified_by, :documents)
            .chronological
            .map { |record| ownership_payload(record) },
          assignments: property.property_assignments.includes(:user).map { |record| assignment_payload(record) },
          inspections: property.inspections.map { |inspection| inspection_payload(inspection) },
          leases:      property.leases.includes(:tenant).with_attached_lease_pdf.map { |lease| lease_payload(lease) },
          maintenance: property.maintenance_requests
            .includes(:cost_allocations, :financial_entries)
            .order(reported_at: :desc)
            .map { |req| maintenance_payload(req) },
          damage_assessments: property.damage_assessments.order(assessed_on: :desc).map { |assessment| damage_assessment_payload(assessment) }
        }
      end

      private

      def property_payload
        {
          id: property.id,
          name: property.name,
          property_type: property.property_type,
          property_subtype: property.property_subtype,
          condition: property.condition,
          current_value: property.current_value,
          original_value: property.original_value,
          cached_total_units: property.cached_total_units,
          cached_total_bedrooms: property.cached_total_bedrooms,
          cover_photo_url: property.cover_photo_url
        }
      end

      def building_payload(building)
        { id: building.id, name: building.name, building_type: building.building_type, description: building.description }
      end

      def unit_payload(unit)
        {
          id: unit.id,
          building_id: unit.building_id,
          unit_number: unit.unit_number,
          name: unit.name,
          unit_type: unit.unit_type,
          bedrooms: unit.bedrooms,
          bathrooms: unit.bathrooms,
          floor_area: unit.floor_area,
          status: unit.status,
          condition: unit.condition
        }
      end

      def room_payload(room)
        {
          id: room.id,
          unit_id: room.unit_id,
          building_id: room.building_id,
          room_name: room.room_name,
          room_type: room.room_type,
          floor_area: room.floor_area,
          floor_number: room.floor_number,
          status: room.status,
          condition: room.condition
        }
      end

      def item_payload(item)
        {
          id: item.id,
          name: item.name,
          item_type_id: item.item_type_id,
          building_id: item.building_id,
          unit_id: item.unit_id,
          room_id: item.room_id,
          serial_number: item.serial_number,
          installed_at: item.installed_at,
          description: item.description
        }
      end

      def assignment_payload(record)
        {
          id: record.id,
          user: { id: record.user.id, name: "#{record.user.first_name} #{record.user.last_name}", email: record.user.email },
          assignment_type: record.assignment_type,
          starts_at: record.starts_at,
          ends_at: record.ends_at
        }
      end

      def inspection_payload(inspection)
        {
          id:              inspection.id,
          inspection_type: inspection.inspection_type,
          status:          inspection.status,
          scheduled_on:    inspection.scheduled_on,
          inspected_on:    inspection.inspected_on,
          locked_at:       inspection.locked_at,
          inspector_id:    inspection.inspector_id,
          notes:           inspection.notes
        }
      end

      def maintenance_payload(req)
        {
          id:          req.id,
          title:       req.title,
          description: req.description,
          category:    req.category,
          priority:    req.priority,
          status:      req.status,
          classification: req.classification,
          suggested_responsibility: req.suggested_responsibility,
          responsibility_status: req.responsibility_status,
          responsibility_notes: req.responsibility_notes,
          responsibility_reviewed_by_id: req.responsibility_reviewed_by_id,
          responsibility_reviewed_at: req.responsibility_reviewed_at,
          source_type: req.source_type,
          source_inspection_id: req.source_inspection_id,
          source_inspection_item_id: req.source_inspection_item_id,
          source_damage_assessment_id: req.source_damage_assessment_id,
          unit_id: req.unit_id,
          room_id: req.room_id,
          lease_id: req.lease_id,
          contractor_id: req.contractor_id,
          assigned_to_id: req.assigned_to_id,
          reported_at: req.reported_at,
          scheduled_on: req.scheduled_on,
          target_completion_on: req.target_completion_on,
          actual_started_at: req.actual_started_at,
          resolved_at: req.resolved_at,
          verified_by_id: req.verified_by_id,
          verified_at: req.verified_at,
          closed_by_id: req.closed_by_id,
          closed_at: req.closed_at,
          estimated_cost: req.estimated_cost,
          approved_cost: req.approved_cost,
          approved_by_id: req.approved_by_id,
          approved_at: req.approved_at,
          actual_cost: req.actual_cost,
          currency: req.currency,
          cost_allocations: req.cost_allocations.map do |allocation|
            {
              responsible_party: allocation.responsible_party,
              status: allocation.status,
              allocated_amount: allocation.allocated_amount,
              allocation_percentage: allocation.allocation_percentage,
              currency: allocation.currency,
              party_id: allocation.party_id
            }
          end,
          financial_entries: req.financial_entries.map do |entry|
            {
              entry_type: entry.entry_type,
              amount: entry.amount,
              currency: entry.currency,
              status: entry.status,
              occurred_on: entry.occurred_on,
              invoice_id: entry.invoice_id,
              invoice_reference: entry.invoice_reference
            }
          end
        }
      end

      def damage_assessment_payload(assessment)
        {
          id: assessment.id,
          description: assessment.description,
          severity: assessment.severity,
          responsibility: assessment.responsibility,
          status: assessment.status,
          estimated_cost: assessment.estimated_cost,
          inspection_id: assessment.inspection_id,
          inspection_item_id: assessment.inspection_item_id,
          assessed_on: assessment.assessed_on
        }
      end
    end
  end
end