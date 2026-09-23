module Api
  module V1
    class AssignmentsController < PropertyResourcesController
      def index
        render json: property.property_assignments.includes(:user).map { |record| {
          id: record.id,
          user: { id: record.user.id, name: "#{record.user.first_name} #{record.user.last_name}", email: record.user.email },
          assignment_type: record.assignment_type,
          starts_at: record.starts_at,
          ends_at: record.ends_at
        } }
      end
    end
  end
end