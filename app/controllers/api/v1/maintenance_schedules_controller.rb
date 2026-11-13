module Api
  module V1
    class MaintenanceSchedulesController < PropertyResourcesController
      include MaintenanceSerialization
      include DocumentSerialization
      include PropertyManagerAuthorization

      before_action :set_schedule, only: %i[update pause resume complete generate]

      def index
        return head :forbidden unless MaintenanceSchedulePolicy.new(current_user, property).index?

        render json: property.maintenance_schedules.order(:next_due_on).map { |schedule| maintenance_schedule_payload(schedule) }
      end

      def create
        return unless authorize_schedule_manager

        schedule = property.maintenance_schedules.new(schedule_params.except(:unit_id, :room_id, :contractor_id, :assigned_to_id).merge(
          organization: current_organization,
          created_by: current_user
        ))
        assign_associations(schedule)
        if schedule.save
          render json: maintenance_schedule_payload(schedule), status: :created
        else
          render json: { errors: schedule.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "A linked record was not found in this property or organization." }, status: :unprocessable_entity
      end

      def update
        return unless authorize_schedule_manager

        @schedule.assign_attributes(schedule_params.except(:unit_id, :room_id, :contractor_id, :assigned_to_id, :status))
        assign_associations(@schedule)
        if @schedule.save
          render json: maintenance_schedule_payload(@schedule)
        else
          render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def pause
        update_status(:pause)
      end

      def resume
        update_status(:resume)
      end

      def complete
        update_status(:complete)
      end

      def generate
        return unless authorize_schedule_manager

        generated = MaintenanceScheduleGenerator.call(@schedule, manual: true)
        render json: {
          schedule: maintenance_schedule_payload(@schedule.reload),
          occurrences: generated.map { |request| maintenance_request_payload(request) }
        }
      end

      private

      def set_schedule
        @schedule = property.maintenance_schedules.find(params[:maintenance_schedule_id])
      end

      def schedule_params
        params.require(:maintenance_schedule).permit(
          :title, :description, :category, :priority, :classification,
          :suggested_responsibility, :frequency, :interval_months, :interval_value, :interval_unit, :starts_on,
          :ends_on, :next_due_on, :target_completion_on, :reminder_days, :generation_mode,
          :estimated_cost, :currency, :unit_id, :room_id, :assigned_to_id, :contractor_id
        )
      end

      def assign_associations(schedule)
        values = schedule_params
        schedule.unit = values[:unit_id].present? ? property.units.find(values[:unit_id]) : nil if values.key?(:unit_id)
        schedule.room = values[:room_id].present? ? property.rooms.find(values[:room_id]) : nil if values.key?(:room_id)
        schedule.contractor = values[:contractor_id].present? ? current_organization.parties.find(values[:contractor_id]) : nil if values.key?(:contractor_id)
        schedule.assigned_to = values[:assigned_to_id].present? ? current_organization.users.find(values[:assigned_to_id]) : nil if values.key?(:assigned_to_id)
      end

      def authorize_schedule_manager
        policy = MaintenanceSchedulePolicy.new(current_user, @schedule || property)
        return true if policy.manage?

        render json: { error: "Only an active property manager can manage property records." }, status: :forbidden
        false
      end

      def update_status(action)
        return unless authorize_schedule_manager

        MaintenanceScheduleLifecycle.call(schedule: @schedule, action: action)
        render json: maintenance_schedule_payload(@schedule)
      rescue MaintenanceScheduleLifecycle::InvalidTransition
        render json: { error: "This schedule status transition is not allowed." }, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
