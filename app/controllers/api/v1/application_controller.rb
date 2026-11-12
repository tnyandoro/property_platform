module Api
  module V1
    class ApplicationController < ::ApplicationController
      include ActiveStorage::SetCurrent

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      private

      # Instantiates the matching Policy class and calls the given query.
      # Raises 403 if the policy returns false.
      def authorize!(record, query)
        policy_class = "#{record.class.name}Policy".constantize
        policy       = policy_class.new(current_user, record)

        unless policy.public_send(query)
          render json: { error: "Not authorized" }, status: :forbidden
          raise ActiveRecord::Rollback
        end
      end

      def render_not_found
        render json: { error: "Resource not found" }, status: :not_found
      end

      def render_bad_request(error)
        render json: { error: error.message }, status: :bad_request
      end
    end
  end
end