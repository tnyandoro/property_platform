class PropertiesController < ApplicationController
  include PropertyAuthorization

  before_action :set_property, only: %i[show update destroy]

  def index
    render json: accessible_properties
  end

  def show
    render json: @property
  end

  def create
    property = current_organization.properties.new(property_params)

    Property.transaction do
      property.save!
      property.property_assignments.create!(
        organization: current_organization,
        user: current_user,
        assignment_type: "manager",
        starts_at: Time.current
      )
    end

    render json: property, status: :created
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    if @property.update(property_params)
      render json: @property
    else
      render json: { errors: @property.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @property.destroy!
    head :no_content
  end

  private

  def set_property
    @property = accessible_property
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