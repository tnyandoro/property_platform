module Api
  module V1
    module Owner
      class DashboardController < Api::V1::ApplicationController
        skip_before_action :require_management_workspace!
        before_action :require_owner_workspace!

        def show
          ownerships = owner_ownerships

          render json: {
            profile: {
              first_name: current_user.first_name,
              last_name: current_user.last_name,
              email: current_user.email
            },
            portfolio: {
              property_count: ownerships.map(&:property_id).uniq.size,
              ownership_count: ownerships.size
            },
            ownerships: ownerships.map { |ownership| ownership_payload(ownership) }
          }
        end

        private

        def owner_ownerships
          PropertyOwnership.joins(:party)
            .joins(
              "INNER JOIN party_accounts ON party_accounts.party_id = property_ownerships.party_id " \
              "AND party_accounts.organization_id = property_ownerships.organization_id"
            )
            .includes(:property)
            .where(
              property_ownerships: {
                organization_id: current_organization.id,
                verification_status: "verified"
              },
              party_accounts: {
                organization_id: current_organization.id,
                user_id: current_user.id,
                status: "verified"
              }
            )
            .merge(PropertyOwnership.active_on(Date.current))
            .order("properties.name ASC, property_ownerships.start_date ASC")
        end

        def ownership_payload(ownership)
          property = ownership.property

          {
            id: ownership.id,
            ownership_percentage: ownership.ownership_percentage,
            start_date: ownership.start_date,
            property: {
              id: property.id,
              name: property.name,
              property_type: property.property_type,
              address: {
                line_1: property.address_line_1,
                line_2: property.address_line_2,
                suburb: property.suburb,
                city: property.city,
                province: property.province,
                postal_code: property.postal_code,
                country: property.country
              }
            }
          }
        end
      end
    end
  end
end
