module Api
  module V1
    class LeasesController < PropertyResourcesController
      include LeaseSerialization
      include PropertyManagerAuthorization

      MAX_PDF_SIZE = Lease::MAX_PDF_SIZE

      def index
        leases = property.leases
          .includes(:unit, :tenant)
          .with_attached_lease_pdf
          .order(start_date: :desc, created_at: :desc)

        render json: leases.map { |lease| lease_payload(lease) }
      end

      def create
        return unless authorize_active_property_manager

        file = params[:lease_pdf]
        return render json: { error: "lease_pdf param is required" }, status: :bad_request unless file.is_a?(ActionDispatch::Http::UploadedFile)
        return render json: { error: "Lease PDF must be 10 MiB or smaller." }, status: :payload_too_large if file.size > MAX_PDF_SIZE
        return render json: { error: "Upload a valid PDF file." }, status: :unprocessable_entity unless pdf_file?(file)

        attributes = lease_params.to_h.symbolize_keys
        unit = property.units.find(attributes.delete(:unit_id))
        tenant_id = attributes.delete(:tenant_id)
        tenant_attributes = attributes.delete(:tenant)
        tenant = resolve_tenant(tenant_id, tenant_attributes)

        blob = nil
        lease = property.leases.new(attributes.merge(
          organization: current_organization,
          unit: unit,
          tenant: tenant
        ))
        lease.status = status_for(lease)

        blob = ActiveStorage::Blob.create_and_upload!(
          io: file,
          filename: file.original_filename,
          content_type: "application/pdf"
        )
        Lease.transaction do
          tenant.save! if tenant&.new_record?
          lease.lease_pdf.attach(blob)
          lease.save!
        end

        render json: lease_payload(lease), status: :created
      rescue ActiveRecord::RecordInvalid => error
        blob&.purge
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def lease_params
        params.require(:lease).permit(
          :unit_id,
          :tenant_id,
          :start_date,
          :end_date,
          :lease_type,
          :monthly_rent,
          :deposit_amount,
          :rent_currency,
          :notice_period_days,
          :terms_summary,
          tenant: %i[name party_type]
        )
      end

      def resolve_tenant(tenant_id, tenant_attributes)
        return current_organization.parties.find(tenant_id) if tenant_id.present?
        return if tenant_attributes.blank?

        tenant_attributes = tenant_attributes.to_h.symbolize_keys
        current_organization.parties.find_or_initialize_by(
          name: tenant_attributes[:name].to_s.strip,
          party_type: tenant_attributes[:party_type].to_s.strip.downcase
        )
      end

      def pdf_file?(file)
        return false unless File.extname(file.original_filename).casecmp?(".pdf")

        file.tempfile.rewind
        signature = file.tempfile.read(5)
        file.tempfile.rewind
        signature == "%PDF-"
      end

      def status_for(lease)
        return "draft" if lease.start_date.blank? || lease.start_date > Date.current
        return "expired" if lease.end_date.present? && lease.end_date < Date.current

        "active"
      end
    end
  end
end
