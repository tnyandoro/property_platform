module Api
  module V1
    class PropertiesController < ApplicationController
      include ::PropertyAuthorization

      before_action :set_property, only: %i[show update destroy]

      def index
        render json: accessible_properties.map { |property| property_payload(property) }
      end

      def show
        render json: property_payload(@property)
      end

      def create
        property = current_organization.properties.new(property_params)
        authorize!(property, :create?)

        Property.transaction do
          property.save!
          property.property_assignments.create!(
            organization: current_organization,
            user: current_user,
            assignment_type: "manager",
            starts_at: Time.current
          )
        end

        render json: property_payload(property), status: :created
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      def update
        authorize!(@property, :update?)
        return if performed?

        if @property.update(property_params)
          render json: property_payload(@property)
        else
          render json: { errors: @property.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        authorize!(@property, :destroy?)
        return if performed?

        @property.destroy!
        head :no_content
      end

      private

      def set_property
        @property = accessible_property
      end

      def property_payload(property)
        {
          id: property.id,
          name: property.name,
          property_type: property.property_type,
          property_subtype: property.property_subtype,
          condition: property.condition,
          address: {
            line_1: property.address_line_1,
            line_2: property.address_line_2,
            suburb: property.suburb,
            city: property.city,
            province: property.province,
            postal_code: property.postal_code,
            country: property.country
          },
          current_value: property.current_value,
          cached_total_units: property.cached_total_units,
          cached_total_bedrooms: property.cached_total_bedrooms,
          cover_photo_url: property.cover_photo_url,
          created_at: property.created_at,
          updated_at: property.updated_at
        }
      end

      def property_params
        params.require(:property).permit(
          :name,
          :property_type,
          :property_subtype,
          :year_established,
          :land_size,
          :building_size,
          :original_value,
          :current_value,
          :address_line_1,
          :address_line_2,
          :suburb,
          :city,
          :province,
          :postal_code,
          :country,
          :latitude,
          :longitude,
          :condition,
          :description
        )
      end
    end
  end
end