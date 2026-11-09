module Api
  module V1
    # POST /api/v1/properties/:property_id/photos
    class PropertyPhotosController < PropertyResourcesController
      def create
        file = params[:file]
        return render json: { error: "file param is required" },
                      status: :bad_request unless file.is_a?(ActionDispatch::Http::UploadedFile)

        blob = ActiveStorage::Blob.create_and_upload!(
          io:           file,
          filename:     file.original_filename,
          content_type: file.content_type
        )

        url = blob.service_url(expires_in: 10.years) rescue nil

        property.update!(cover_photo_url: url)

        render json: { cover_photo_url: url }
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
