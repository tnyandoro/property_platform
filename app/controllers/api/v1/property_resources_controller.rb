module Api
  module V1
    class PropertyResourcesController < ApplicationController
      include ::PropertyAuthorization

      before_action :set_property

      private

      attr_reader :property

      def set_property
        @property = accessible_nested_property
      end
    end
  end
end