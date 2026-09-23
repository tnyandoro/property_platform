module Api
  module V1
    class BuildingsController < PropertyResourcesController
      def index
        render json: property.buildings.map { |building| {
          id: building.id,
          name: building.name,
          building_type: building.building_type,
          description: building.description,
          units_count: building.units.count
        } }
      end
    end
  end
end