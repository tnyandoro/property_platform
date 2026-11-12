require "test_helper"

class PropertiesTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Acme Properties")
    @user = @organization.users.create!(
      email: "agent@example.com",
      first_name: "Ada",
      last_name: "Agent",
      password: "password123"
    )
    @other_organization = Organization.create!(name: "Other Properties")
    @other_user = @other_organization.users.create!(
      email: "other@example.com",
      first_name: "Owen",
      last_name: "Other",
      password: "password123"
    )
  end

  test "requires authentication" do
    get api_v1_properties_path

    assert_response :unauthorized
  end

  test "creates a property and assigns it to the authenticated user" do
    authenticate_as(@user)

    assert_difference ["Property.count", "PropertyAssignment.count"], 1 do
      post api_v1_properties_path, params: {
        property: { name: "Main Office", property_type: "commercial" }
      }, headers: @auth_headers, as: :json
    end

    assert_response :created
    property = Property.order(:created_at).last
    assert_equal @organization, property.organization
    assert_equal @user, property.property_assignments.last.user
  end

  test "uploads a cover photo for an assigned property" do
    property = assigned_property
    authenticate_as(@user)
    upload = Rack::Test::UploadedFile.new(
      StringIO.new("test image"),
      "image/jpeg",
      true,
      original_filename: "property.jpg"
    )

    assert_difference "ActiveStorage::Blob.count", 1 do
      post "/api/v1/properties/#{property.id}/photos",
           params: { file: upload },
           headers: @auth_headers
    end

    assert_response :success
    photo_url = JSON.parse(response.body).fetch("cover_photo_url")
    assert photo_url.present?
    assert_equal photo_url, property.reload.cover_photo_url
  end

  test "rejects cover photos above the storage size limit before creating a blob" do
    property = assigned_property
    authenticate_as(@user)
    upload = Rack::Test::UploadedFile.new(
      StringIO.new("x" * (Api::V1::PropertyResourcesController::MAX_PHOTO_UPLOAD_SIZE + 1)),
      "image/jpeg",
      true,
      original_filename: "large-property.jpg"
    )

    assert_no_difference "ActiveStorage::Blob.count" do
      post "/api/v1/properties/#{property.id}/photos",
           params: { file: upload },
           headers: @auth_headers
    end

    assert_response :payload_too_large
    assert_equal Api::V1::PropertyResourcesController::PHOTO_SIZE_ERROR,
                 JSON.parse(response.body).fetch("error")
  end

  test "lists only actively assigned properties in the current organization" do
    visible = @organization.properties.create!(name: "Visible", property_type: "residential")
    visible.property_assignments.create!(
      organization: @organization,
      user: @user,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    @organization.properties.create!(name: "Unassigned", property_type: "residential")
    cross_tenant = @other_organization.properties.create!(name: "Other", property_type: "residential")
    cross_tenant.property_assignments.create!(
      organization: @other_organization,
      user: @other_user,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )

    authenticate_as(@user)
    get api_v1_properties_path, headers: @auth_headers

    assert_response :success
    names = JSON.parse(response.body).pluck("name")
    assert_equal ["Visible"], names
  end

  test "does not allow access to a property assigned to another user" do
    property = @organization.properties.create!(name: "Restricted", property_type: "residential")
    property.property_assignments.create!(
      organization: @organization,
      user: @other_user,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )

    authenticate_as(@user)
    get api_v1_property_path(property), headers: @auth_headers

    assert_response :not_found
  end

  test "updates and deletes an assigned property" do
    property = @organization.properties.create!(name: "Old Name", property_type: "residential")
    property.property_assignments.create!(
      organization: @organization,
      user: @user,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    authenticate_as(@user)

    patch api_v1_property_path(property), params: {
      property: { name: "New Name" }
    }, headers: @auth_headers, as: :json
    assert_response :success
    assert_equal "New Name", property.reload.name

    delete api_v1_property_path(property), headers: @auth_headers
    assert_response :no_content
    assert_not Property.exists?(property.id)
  end

  test "returns the property portfolio resources" do
    property = assigned_property
    authenticate_as(@user)

    get api_v1_portfolio_path(property), headers: @auth_headers

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal property.id, payload.dig("property", "id")
    assert payload.key?("buildings")
    assert payload.key?("units")
    assert payload.key?("rooms")
    assert payload.key?("items")
    assert payload.key?("ownership")
    assert payload.key?("assignments")
    assert payload.key?("inspections")
  end

  test "returns nested resources only for an assigned property" do
    property = assigned_property
    authenticate_as(@user)

    get api_v1_buildings_path(property), headers: @auth_headers
    assert_response :success

    get api_v1_units_path(property), headers: @auth_headers
    assert_response :success

    get api_v1_inspections_path(property), headers: @auth_headers
    assert_response :success

    get api_v1_ownership_path(property), headers: @auth_headers
    assert_response :success

    get api_v1_assignments_path(property), headers: @auth_headers
    assert_response :success
  end

  test "does not expose nested resources for another tenant" do
    property = @other_organization.properties.create!(name: "Other Property", property_type: "residential")
    property.property_assignments.create!(
      organization: @other_organization,
      user: @other_user,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    authenticate_as(@user)

    get api_v1_portfolio_path(property), headers: @auth_headers

    assert_response :not_found
  end

  private

  def assigned_property
    property = @organization.properties.create!(name: "Assigned Property", property_type: "residential")
    property.property_assignments.create!(
      organization: @organization,
      user: @user,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    property
  end

  def authenticate_as(user)
    post api_v1_login_path, params: {
      email: user.email,
      password: "password123"
    }, as: :json
    assert_response :created
    token = JSON.parse(response.body).fetch("token")
    @auth_headers = { "Authorization" => "Bearer #{token}" }
  end
end