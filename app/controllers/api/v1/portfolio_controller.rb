module Api
  module V1
    class PortfolioController < PropertyResourcesController
      def show
        render json: {
          property: property_payload,
          buildings: property.buildings.map { |building| building_payload(building) },
          units: property.units.map { |unit| unit_payload(unit) },
          rooms: property.rooms.map { |room| room_payload(room) },
          items: property.property_items.map { |item| item_payload(item) },
          ownership: property.property_ownerships.includes(:party).map { |record| ownership_payload(record) },
          assignments: property.property_assignments.includes(:user).map { |record| assignment_payload(record) },
          inspections: property.inspections.map { |inspection| inspection_payload(inspection) }
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
          cached_total_units: property.cached_total_units,
          cached_total_bedrooms: property.cached_total_bedrooms
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

      def ownership_payload(record)
        {
          id: record.id,
          party: { id: record.party.id, name: record.party.name, party_type: record.party.party_type },
          ownership_percentage: record.ownership_percentage,
          start_date: record.start_date,
          end_date: record.end_date,
          transfer_type: record.transfer_type,
          transfer_value: record.transfer_value,
          notes: record.notes
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
          id: inspection.id,
          inspection_type: inspection.inspection_type,
          status: inspection.status,
          scheduled_on: inspection.scheduled_on,
          inspected_on: inspection.inspected_on,
          locked_at: inspection.locked_at,
          inspector_id: inspection.inspector_id,
          notes: inspection.notes
        }
      end
    end
  end
end