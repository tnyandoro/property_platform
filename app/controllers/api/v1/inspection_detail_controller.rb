module Api
  module V1
    class InspectionDetailController < PropertyResourcesController
      def show
        inspection = property.inspections.includes(inspection_rooms: :inspection_items).find(params[:inspection_id])

        render json: {
          inspection: inspection_payload(inspection),
          rooms: inspection.inspection_rooms.map do |room|
            {
              id: room.id,
              room_name: room.room_name,
              room_type: room.room_type,
              floor_number: room.floor_number,
              notes: room.notes,
              items: room.inspection_items.map { |item| item_payload(item) }
            }
          end
        }
      end

      def update
        inspection = property.inspections.includes(inspection_rooms: :inspection_items).find(params[:inspection_id])
        return render json: { error: "Locked inspections cannot be changed" }, status: :unprocessable_entity if inspection.locked_at.present?

        Inspection.transaction do
          inspection.update!(inspection_update_params)
          params.require(:rooms).each do |room_params|
            room = inspection.inspection_rooms.find(room_params[:id])
            room.update!(notes: room_params[:notes]) if room_params.key?(:notes)

            room_params.fetch(:items, []).each do |item_params|
              item = room.inspection_items.find(item_params[:id])
              item.update!(item_update_params(item_params))
            end
          end
        end

        render json: inspection_payload(inspection.reload)
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

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

      def item_payload(item)
        {
          id: item.id,
          item_name: item.item_name,
          item_type_name: item.item_type_name,
          condition: item.condition,
          condition_score: item.condition_score,
          damage_description: item.damage_description,
          estimated_cost: item.estimated_cost,
          responsibility: item.responsibility,
          notes: item.notes
        }
      end

      def inspection_update_params
        params.permit(:status, :inspected_on, :notes).slice(:status, :inspected_on, :notes)
      end

      def item_update_params(item_params)
        item_params.permit(
          :condition,
          :condition_score,
          :damage_description,
          :estimated_cost,
          :responsibility,
          :notes
        )
      end
    end
  end
end