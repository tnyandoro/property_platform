module Api
  module V1
    class UnitsController < PropertyResourcesController
      def index
        render json: property.units.map { |unit| {
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
        } }
      end
    end
  end
end