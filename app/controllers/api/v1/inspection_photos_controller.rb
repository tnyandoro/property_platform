module Api
  module V1
    # POST /api/v1/properties/:property_id/inspections/:inspection_id/photos
    # GET  /api/v1/properties/:property_id/inspections/:inspection_id/photos
    class InspectionPhotosController < PropertyResourcesController
      def index
        inspection = scoped_inspection
        photos = inspection.inspection_photos.order(created_at: :asc)
        render json: photos.map { |photo| photo_payload(photo) }
      end

      def create
        inspection = scoped_inspection
        return render json: { error: "Locked inspections cannot be changed" },
                      status: :unprocessable_entity if inspection.locked?

        file = params[:file]
        return render json: { error: "file param is required" },
                      status: :bad_request unless file.is_a?(ActionDispatch::Http::UploadedFile)

        blob = ActiveStorage::Blob.create_and_upload!(
          io:           file,
          filename:     file.original_filename,
          content_type: file.content_type
        )

        photo = inspection.inspection_photos.create!(
          organization:      current_organization,
          storage_key:       blob.key,
          content_type:      blob.content_type,
          caption:           params[:caption],
          taken_at:          params[:taken_at],
          inspection_room_id: params[:inspection_room_id],
          inspection_item_id: params[:inspection_item_id]
        )

        render json: photo_payload(photo), status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def scoped_inspection
        property.inspections.find(params[:inspection_id])
      end

      def photo_payload(photo)
        blob = ActiveStorage::Blob.find_by(key: photo.storage_key)
        url  = blob&.service_url(expires_in: 1.hour) rescue nil

        {
          id:                  photo.id,
          inspection_id:       photo.inspection_id,
          inspection_room_id:  photo.inspection_room_id,
          inspection_item_id:  photo.inspection_item_id,
          storage_key:         photo.storage_key,
          content_type:        photo.content_type,
          caption:             photo.caption,
          taken_at:            photo.taken_at,
          url:                 url,
          created_at:          photo.created_at
        }
      end
    end
  end
end
