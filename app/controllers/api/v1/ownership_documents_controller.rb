module Api
  module V1
    class OwnershipDocumentsController < PropertyResourcesController
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
        title_deed
        sale_agreement
        transfer_document
        inheritance_document
        court_order
        other
      ].freeze

      before_action :set_ownership

      def index
        documents = ownership.documents.order(:created_at, :id)
        render json: documents.map { |document| document_payload(document) }
      end

      def create
        return unless authorize_active_property_manager

        file = params[:file]
        return render json: { error: "file param is required" }, status: :bad_request unless file.is_a?(ActionDispatch::Http::UploadedFile)
        return render json: { error: "Document must be 10 MiB or smaller." }, status: :payload_too_large if file.size > MAX_DOCUMENT_UPLOAD_SIZE
        return render json: { error: "Unsupported document file type." }, status: :unprocessable_entity unless ALLOWED_CONTENT_TYPES.include?(file.content_type)

        metadata = params.permit(:document_type, :title, :description)
        document_type = metadata[:document_type]
        return render json: { error: "Choose a document type." }, status: :unprocessable_entity unless DOCUMENT_TYPES.include?(document_type)

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: file.original_filename,
          content_type: file.content_type
        )
        document = Document.create!(
          organization: current_organization,
          property: property,
          property_ownership: ownership,
          uploaded_by: current_user,
          document_type: document_type,
          title: metadata[:title].to_s.strip.presence || file.original_filename,
          description: metadata[:description],
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

      attr_reader :ownership

      def set_ownership
        @ownership = property.property_ownerships.find(params[:ownership_id])
      end

    end
  end
end
