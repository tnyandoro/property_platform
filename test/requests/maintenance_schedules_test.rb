require "test_helper"

class MaintenanceSchedulesTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Maintenance schedules API #{SecureRandom.hex(4)}")
    @manager = @organization.users.create!(
      email: "schedule-manager-#{SecureRandom.hex(4)}@example.com",
      first_name: "Mara",
      last_name: "Manager",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Schedule API property", property_type: "residential")
    @property.property_assignments.create!(
      organization: @organization,
      user: @manager,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    authenticate_as(@manager)
  end

  test "creates, lists, updates and completes a schedule" do
    post schedules_path,
         params: { maintenance_schedule: schedule_attributes },
         headers: @auth_headers,
         as: :json

    assert_response :created
    schedule_id = JSON.parse(response.body).fetch("id")
    assert_equal "active", JSON.parse(response.body).fetch("status")

    get schedules_path, headers: @auth_headers
    assert_response :success
    assert_equal schedule_id, JSON.parse(response.body).sole.fetch("id")

    patch "#{schedules_path}/#{schedule_id}",
          params: { maintenance_schedule: { title: "Updated service" } },
          headers: @auth_headers,
          as: :json
    assert_response :success
    assert_equal "Updated service", JSON.parse(response.body).fetch("title")

    post "#{schedules_path}/#{schedule_id}/pause", headers: @auth_headers, as: :json
    assert_response :success
    assert_equal "paused", JSON.parse(response.body).fetch("status")

    post "#{schedules_path}/#{schedule_id}/resume", headers: @auth_headers, as: :json
    assert_response :success
    assert_equal "active", JSON.parse(response.body).fetch("status")

    post "#{schedules_path}/#{schedule_id}/complete", headers: @auth_headers, as: :json
    assert_response :success
    assert_equal "completed", JSON.parse(response.body).fetch("status")

    post "#{schedules_path}/#{schedule_id}/resume", headers: @auth_headers, as: :json
    assert_response :unprocessable_entity
  end

  test "generates due work once through the API" do
    due_on = Date.current - 1.day
    post schedules_path,
         params: {
           maintenance_schedule: schedule_attributes(
             frequency: "monthly",
             starts_on: due_on,
             next_due_on: due_on,
             generation_mode: "proposed"
           )
         },
         headers: @auth_headers,
         as: :json
    assert_response :created
    schedule_id = JSON.parse(response.body).fetch("id")

    assert_difference "MaintenanceRequest.count", 1 do
      post "#{schedules_path}/#{schedule_id}/generate", headers: @auth_headers, as: :json
      assert_response :success
      assert_equal "awaiting_approval", JSON.parse(response.body).dig("occurrences", 0, "status")
    end

    assert_no_difference "MaintenanceRequest.count" do
      post "#{schedules_path}/#{schedule_id}/generate", headers: @auth_headers, as: :json
      assert_response :success
      assert_empty JSON.parse(response.body).fetch("occurrences")
    end
  end

  test "one-time schedules retain target completion on the generated work order" do
    due_on = Date.current
    target_on = due_on + 5.days
    post schedules_path,
         params: {
           maintenance_schedule: schedule_attributes(
             frequency: "once",
             starts_on: due_on,
             next_due_on: due_on,
             target_completion_on: target_on
           )
         },
         headers: @auth_headers,
         as: :json

    assert_response :created
    schedule_id = JSON.parse(response.body).fetch("id")
    assert_equal target_on.to_s, JSON.parse(response.body).fetch("target_completion_on")

    post "#{schedules_path}/#{schedule_id}/generate", headers: @auth_headers, as: :json

    assert_response :success
    occurrence = JSON.parse(response.body).fetch("occurrences").sole
    assert_equal due_on.to_s, occurrence.fetch("scheduled_on")
    assert_equal target_on.to_s, occurrence.fetch("target_completion_on")
    assert_equal "completed", JSON.parse(response.body).dig("schedule", "status")
  end

  test "does not allow a manager to address another property's schedule through this property" do
    other_property = @organization.properties.create!(name: "Unassigned schedule property", property_type: "residential")
    other_schedule = other_property.maintenance_schedules.create!(
      organization: @organization,
      created_by: @manager,
      title: "Other property work",
      starts_on: Date.current,
      next_due_on: Date.current
    )

    post "#{schedules_path}/#{other_schedule.id}/pause", headers: @auth_headers, as: :json

    assert_response :not_found
  end

  test "only an active property manager can create schedules" do
    viewer = @organization.users.create!(
      email: "schedule-viewer-#{SecureRandom.hex(4)}@example.com",
      first_name: "Val",
      last_name: "Viewer",
      password: "password123"
    )
    @property.property_assignments.create!(
      organization: @organization,
      user: viewer,
      assignment_type: "viewer",
      starts_at: 1.hour.ago
    )
    authenticate_as(viewer)

    post schedules_path,
         params: { maintenance_schedule: schedule_attributes },
         headers: @auth_headers,
         as: :json

    assert_response :forbidden
  end

  private

  def schedules_path
    "/api/v1/properties/#{@property.id}/maintenance_schedules"
  end

  def schedule_attributes(overrides = {})
    {
      title: "Quarterly pump service",
      priority: "medium",
      frequency: "quarterly",
      starts_on: Date.current.to_s,
      next_due_on: Date.current.to_s,
      currency: "ZAR"
    }.merge(overrides)
  end

  def authenticate_as(user)
    post api_v1_login_path, params: { email: user.email, password: "password123" }, as: :json
    assert_response :created
    @auth_headers = { "Authorization" => "Bearer #{JSON.parse(response.body).fetch('token')}" }
  end
end
