require "test_helper"

class InspectionPhotoTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Photo Org #{SecureRandom.hex(4)}")
    @user = @organization.users.create!(
      email: "photo-user-#{SecureRandom.hex(4)}@example.com",
      first_name: "Pat",
      last_name: "Photographer",
      password: "password123"
    )

    @property = @organization.properties.create!(
      name: "Photo House",
      property_type: "residential"
    )

    @building = @property.buildings.create!(
      organization: @organization,
      name: "Main"
    )

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

    @inspection = build_inspection
    @inspection_room = build_inspection_room(@inspection)
    @item = build_inspection_item(@inspection, @inspection_room)
  end

  test "accepts a photo attached to a room" do
    photo = InspectionPhoto.new(
      organization: @organization,
      inspection: @inspection,
      inspection_room: @inspection_room,
      storage_key: "photo-room-key"
    )

    assert photo.valid?, photo.errors.full_messages.inspect
  end

  test "accepts a photo attached to an item" do
    photo = InspectionPhoto.new(
      organization: @organization,
      inspection: @inspection,
      inspection_item: @item,
      storage_key: "photo-item-key"
    )

    assert photo.valid?, photo.errors.full_messages.inspect
  end

  test "rejects a photo without a room or item" do
    photo = InspectionPhoto.new(
      organization: @organization,
      inspection: @inspection,
      storage_key: "photo-no-parent-key"
    )

    assert_not photo.valid?
    assert_includes photo.errors[:base],
                    "must belong to an inspection room or inspection item"
  end

  test "rejects a room belonging to another inspection" do
    other_inspection = build_inspection
    photo = InspectionPhoto.new(
      organization: @organization,
      inspection: @inspection,
      inspection_room: build_inspection_room(other_inspection),
      storage_key: "photo-wrong-room-key"
    )

    assert_not photo.valid?
    assert photo.errors[:inspection_room].any?
  end

  test "rejects an item belonging to another inspection" do
    other_inspection = build_inspection
    other_room = build_inspection_room(other_inspection)
    other_item = build_inspection_item(other_inspection, other_room)

    photo = InspectionPhoto.new(
      organization: @organization,
      inspection: @inspection,
      inspection_item: other_item,
      storage_key: "photo-wrong-item-key"
    )

    assert_not photo.valid?
    assert photo.errors[:inspection_item].any?
  end

  test "rejects an item that belongs to a different selected room" do
    other_room = build_inspection_room(@inspection)

    photo = InspectionPhoto.new(
      organization: @organization,
      inspection: @inspection,
      inspection_room: other_room,
      inspection_item: @item,
      storage_key: "photo-mismatched-room-item-key"
    )

    assert_not photo.valid?
    assert photo.errors[:inspection_item].any?
  end

  private

  def build_inspection
    @organization.inspections.create!(
      property: @property,
      inspector: @user,
      inspection_type: "routine",
      status: "completed"
    )
  end

  def build_inspection_room(inspection)
    inspection.inspection_rooms.create!(
      organization: @organization,
      property_id: @property.id,
      building_id: @building.id,
      unit_id: @unit.id,
      room_id: @room.id,
      room_name: "Living Room",
      room_type: "living_room"
    )
  end

  def build_inspection_item(inspection, room)
    room.inspection_items.create!(
      organization: @organization,
      inspection: inspection,
      item_name: "Window",
      item_type_name: "Windows",
      condition: "good",
      condition_score: 5
    )
  end
end
