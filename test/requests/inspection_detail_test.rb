require "test_helper"

class InspectionDetailTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Inspection Group")
    @user = @organization.users.create!(
      email: "inspector@example.com",
      first_name: "Iris",
      last_name: "Inspector",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Inspection House", property_type: "residential")
    @property.property_assignments.create!(
      organization: @organization,
      user: @user,
      assignment_type: "inspector",
      starts_at: 1.hour.ago
    )
    @inspection = @organization.inspections.create!(
      property: @property,
      inspector: @user,
      inspection_type: "routine",
      status: "completed"
    )
    @building = @property.buildings.create!(organization: @organization, name: "Main House")
    @unit = @building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "1",
      unit_type: "residential"
    )
    @room = @unit.rooms.create!(
      organization: @organization,
      building: @building,
      property: @property,
      room_name: "Living Room",
      room_type: "living_room"
    )
  end

  test "returns inspection room and item snapshots for an assigned property" do
    room = @inspection.inspection_rooms.create!(
      organization: @organization,
      property_id: @property.id,
      building_id: @building.id,
      unit_id: @unit.id,
      room_id: @room.id,
      room_name: "Living Room",
      room_type: "living_room"
    )
    room.inspection_items.create!(
      organization: @organization,
      inspection: @inspection,
      item_name: "Sofa",
      item_type_name: "Furniture",
      condition: "good",
      condition_score: 5,
      notes: "Light scuffs on the left arm."
    )

    post api_v1_login_path, params: { email: @user.email, password: "password123" }, as: :json
    token = JSON.parse(response.body).fetch("token")
    get api_v1_inspection_detail_path(@property, @inspection), headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "routine", payload.dig("inspection", "inspection_type")
    assert_equal "Living Room", payload.dig("rooms", 0, "room_name")
    assert_equal 5, payload.dig("rooms", 0, "items", 0, "condition_score")
    assert_equal "Light scuffs on the left arm.", payload.dig("rooms", 0, "items", 0, "notes")
  end

  test "schedules a draft inspection for an assigned property" do
    post api_v1_login_path, params: { email: @user.email, password: "password123" }, as: :json
    token = JSON.parse(response.body).fetch("token")

    assert_difference "Inspection.count", 1 do
      post api_v1_inspections_path(@property),
           params: { inspection: { inspection_type: "move_out", scheduled_on: "2026-10-01" } },
           headers: { "Authorization" => "Bearer #{token}" },
           as: :json
    end

    assert_response :created
    assert_equal "draft", JSON.parse(response.body).fetch("status")
    assert_equal @user.id, Inspection.order(:created_at).last.inspector_id
  end

  test "updates room checklist ratings for an unlocked inspection" do
    room = @inspection.inspection_rooms.create!(
      organization: @organization,
      property_id: @property.id,
      building_id: @building.id,
      unit_id: @unit.id,
      room_id: @room.id,
      room_name: "Living Room",
      room_type: "living_room"
    )
    item = room.inspection_items.create!(
      organization: @organization,
      inspection: @inspection,
      item_name: "Windows",
      item_type_name: "Windows",
      condition: "good",
      condition_score: 5
    )

    post api_v1_login_path, params: { email: @user.email, password: "password123" }, as: :json
    token = JSON.parse(response.body).fetch("token")
    patch api_v1_inspection_detail_path(@property, @inspection),
          params: {
            status: "completed",
            rooms: [{ id: room.id, items: [{ id: item.id, condition: "fair", condition_score: 3, notes: "Small chip near the lower edge." }] }]
          },
          headers: { "Authorization" => "Bearer #{token}" },
          as: :json

    assert_response :success
    assert_equal 3, item.reload.condition_score
    assert_equal "Small chip near the lower edge.", item.notes
    assert_equal "completed", @inspection.reload.status
  end

  test "provisions a complete checklist when an inspection has no snapshots" do
    post api_v1_login_path, params: { email: @user.email, password: "password123" }, as: :json
    token = JSON.parse(response.body).fetch("token")

    get api_v1_inspection_detail_path(@property, @inspection), headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload.fetch("rooms").length
    assert_operator payload.dig("rooms", 0, "items").length, :>, 1
  end
end
