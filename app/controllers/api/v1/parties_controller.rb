module Api
  module V1
    class PartiesController < ApplicationController
      def index
        parties = current_organization.parties.order(:name, :party_type)
        render json: parties.map { |party| { id: party.id, name: party.name, party_type: party.party_type } }
      end
    end
  end
end
