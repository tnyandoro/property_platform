module Api
  module V1
    class OwnershipController < PropertyResourcesController
      include OwnershipSerialization
      include PropertyManagerAuthorization

      def index
        records = property.property_ownerships
          .includes(:party, :verified_by, :documents)
          .chronological

        render json: records.map { |record| ownership_payload(record) }
      end

      def create
        return unless authorize_active_property_manager

        attributes = ownership_params
        record = nil
        Property.transaction do
          property.lock!
          record = property.property_ownerships.new(organization: current_organization)
          assign_record_attributes(record, attributes)
          record.save!
        end

        render json: ownership_payload(record), status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        return unless authorize_active_property_manager

        record = nil
        Property.transaction do
          property.lock!
          record = property.property_ownerships.lock.find(params[:ownership_id])
          assign_record_attributes(record, ownership_params)
          record.save!
        end

        render json: ownership_payload(record.reload)
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def close
        return unless authorize_active_property_manager

        begin
          end_date = Date.iso8601(params.require(:end_date).to_s)
        rescue ArgumentError
          return render json: { errors: ["Enter a valid ownership end date."] }, status: :unprocessable_entity
        end

        record = nil
        Property.transaction do
          property.lock!
          record = property.property_ownerships.lock.find(params[:ownership_id])
          record.update!(end_date: end_date)
        end

        render json: ownership_payload(record.reload)
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def transfer
        return unless authorize_active_property_manager

        attributes = transfer_params
        begin
          effective_on = Date.iso8601(attributes[:effective_on].to_s)
        rescue ArgumentError
          return render json: { errors: ["Enter a valid effective date."] }, status: :unprocessable_entity
        end
        incoming_owners = attributes.fetch(:incoming_owners, [])
        if incoming_owners.empty?
          return render json: { errors: ["Add at least one incoming owner."] }, status: :unprocessable_entity
        end

        common_attributes = attributes.to_h.symbolize_keys.except(:effective_on, :incoming_owners, :verification_status)
        closed_records = []
        created_records = []

        Property.transaction do
          property.lock!
          closed_records = property.property_ownerships.active_on(effective_on).lock.to_a
          closed_records.each { |record| record.update!(end_date: effective_on) }

          incoming_owners.each do |owner_attributes|
            owner_attributes = owner_attributes.to_h.symbolize_keys
            party_id = owner_attributes.delete(:party_id)
            party_attributes = owner_attributes.delete(:party)
            record = property.property_ownerships.new(
              common_attributes.merge(
                start_date: effective_on,
                end_date: nil,
                ownership_percentage: owner_attributes[:ownership_percentage],
                verification_status: "unverified",
                organization: current_organization
              )
            )
            record.party = resolve_party(party_id, party_attributes)
            record.save!
            created_records << record
          end
        end

        total_percentage = created_records.sum { |record| record.ownership_percentage.to_d }
        warnings = if total_percentage < 100
          ["Incoming ownership shares total #{total_percentage.to_s('F')}%; the remaining share is unassigned."]
        else
          []
        end
        render json: {
          records: created_records.map { |record| ownership_payload(record) },
          closed_ownership_ids: closed_records.map(&:id),
          warnings: warnings
        }, status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def ownership_params
        params.require(:property_ownership).permit(
          :party_id,
          :ownership_percentage,
          :start_date,
          :end_date,
          :transfer_type,
          :transfer_value,
          :valuation_at_transfer,
          :currency,
          :transfer_reference,
          :conveyancer,
          :notes,
          :verification_status,
          party: %i[name party_type]
        )
      end

      def transfer_params
        params.require(:transfer).permit(
          :effective_on,
          :transfer_type,
          :transfer_value,
          :valuation_at_transfer,
          :currency,
          :transfer_reference,
          :conveyancer,
          :notes,
          incoming_owners: [
            :party_id,
            :ownership_percentage,
            { party: %i[name party_type] }
          ]
        )
      end

      def assign_record_attributes(record, attributes)
        attributes = attributes.to_h.symbolize_keys
        party_id = attributes.delete(:party_id)
        party_attributes = attributes.delete(:party)
        verification_status = attributes.delete(:verification_status)

        %i[start_date end_date].each do |field|
          next unless attributes.key?(field)
          next if attributes[field].blank?

          begin
            attributes[field] = Date.iso8601(attributes[field].to_s)
          rescue ArgumentError
            record.errors.add(field, "must be a valid date")
            raise ActiveRecord::RecordInvalid.new(record)
          end
        end

        record.assign_attributes(attributes)
        record.party = resolve_party(party_id, party_attributes) if party_id.present? || party_attributes.present?
        apply_verification(record, verification_status) if verification_status.present?
      end

      def resolve_party(party_id, party_attributes)
        return current_organization.parties.find(party_id) if party_id.present?
        return if party_attributes.blank?

        party_attributes = party_attributes.to_h.symbolize_keys
        current_organization.parties.find_or_create_by!(
          name: party_attributes[:name].to_s.strip,
          party_type: party_attributes[:party_type].to_s.strip.downcase
        )
      end

      def apply_verification(record, status)
        record.verification_status = status
        if status == "verified"
          record.verified_by = current_user
          record.verified_at = Time.current
        else
          record.verified_by = nil
          record.verified_at = nil
        end
      end

    end
  end
end
