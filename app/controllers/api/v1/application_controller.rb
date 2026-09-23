module Api
  module V1
    class ApplicationController < ::ApplicationController
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      private

      def render_not_found
        render json: { error: "Resource not found" }, status: :not_found
      end

      def render_bad_request(error)
        render json: { error: error.message }, status: :bad_request
      end
    end
  end
end