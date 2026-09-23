module Api
  module V1
    class OwnershipController < PropertyResourcesController
      def index
        render json: property.property_ownerships.includes(:party).map { |record| {
          id: record.id,
          party: { id: record.party.id, name: record.party.name, party_type: record.party.party_type },
          ownership_percentage: record.ownership_percentage,
          start_date: record.start_date,
          end_date: record.end_date,
          transfer_type: record.transfer_type,
          transfer_value: record.transfer_value,
          notes: record.notes
        } }
      end
    end
  end
end