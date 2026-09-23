module Api
  module V1
    class InspectionsController < PropertyResourcesController
      def index
        render json: property.inspections.map { |inspection| {
          id: inspection.id,
          inspection_type: inspection.inspection_type,
          status: inspection.status,
          scheduled_on: inspection.scheduled_on,
          inspected_on: inspection.inspected_on,
          locked_at: inspection.locked_at,
          inspector_id: inspection.inspector_id,
          notes: inspection.notes
        } }
      end

      def create
        inspection = property.inspections.new(inspection_params)
        inspection.organization = current_organization
        inspection.inspector = current_user
        inspection.status = "draft"

        if inspection.save
          render json: inspection_payload(inspection), status: :created
        else
          render json: { errors: inspection.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def inspection_params
        params.require(:inspection).permit(:inspection_type, :scheduled_on, :notes)
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