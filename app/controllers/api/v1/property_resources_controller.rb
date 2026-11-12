module Api
  module V1
    class PropertyResourcesController < ApplicationController
      MAX_PHOTO_UPLOAD_SIZE = 10 * 1024 * 1024
      PHOTO_SIZE_ERROR = "Image must be 10 MiB or smaller."

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