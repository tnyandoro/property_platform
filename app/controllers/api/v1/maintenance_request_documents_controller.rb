module Api
  module V1
    class MaintenanceRequestDocumentsController < PropertyResourcesController
      include DocumentSerialization
      include PropertyManagerAuthorization

      MAX_DOCUMENT_UPLOAD_SIZE = 10 * 1024 * 1024
      ALLOWED_CONTENT_TYPES = %w[
        application/pdf
        application/msword
        application/vnd.openxmlformats-officedocument.wordprocessingml.document
        image/jpeg
        image/png
        image/webp
      ].freeze
      DOCUMENT_TYPES = %w[
        quotation approval work_order before_photo after_photo invoice receipt
        payment_proof completion_report compliance_certificate other
      ].freeze

      before_action :set_request

      def index
        return head :forbidden unless MaintenanceRequestPolicy.new(current_user, @request).show?

        render json: @request.documents.order(:created_at, :id).map { |document| document_payload(document) }
      end

      def create
        return unless authorize_active_property_manager

        file = params[:file]
        return render json: { error: "file param is required" }, status: :bad_request unless file.is_a?(ActionDispatch::Http::UploadedFile)
        return render json: { error: "Document must be 10 MiB or smaller." }, status: :payload_too_large if file.size > MAX_DOCUMENT_UPLOAD_SIZE
        return render json: { error: "Unsupported document file type." }, status: :unprocessable_entity unless ALLOWED_CONTENT_TYPES.include?(file.content_type)

        document_type = params[:document_type]
        return render json: { error: "Choose a valid document type." }, status: :unprocessable_entity unless DOCUMENT_TYPES.include?(document_type)

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: file.original_filename,
          content_type: file.content_type
        )
        document = @request.documents.create!(
          organization: current_organization,
          property: property,
          uploaded_by: current_user,
          document_type: document_type,
          title: params[:title].to_s.strip.presence || file.original_filename,
          description: params[:description],
          storage_key: blob.key,
          content_type: blob.content_type,
          file_size_bytes: blob.byte_size
        )
        render json: document_payload(document), status: :created
      rescue ActiveRecord::RecordInvalid => error
        blob&.purge
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def set_request
        @request = property.maintenance_requests.find(params[:maintenance_request_id])
      end
    end
  end
end
