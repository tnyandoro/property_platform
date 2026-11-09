require "test_helper"

class InspectionAmendmentTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Amendment Org #{SecureRandom.hex(4)}")
    @user = @organization.users.create!(
      email: "amender@example.com",
      first_name: "Amy",
      last_name: "Amender",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Amendment House", property_type: "residential")
    @building = @property.buildings.create!(organization: @organization, name: "Main")
    @unit     = @building.units.create!(
      organization: @organization, property: @property,
      unit_number: "1", unit_type: "residential"
    )
    @room = @unit.rooms.create!(
      organization: @organization, building: @building, property: @property,
      room_name: "Living Room", room_type: "living_room"
    )
    @inspection = @organization.inspections.create!(
      property: @property, inspector: @user,
      inspection_type: "routine", status: "completed"
    )
    @inspection_room = @inspection.inspection_rooms.create!(
      organization: @organization,
      property_id: @property.id,
      building_id: @building.id,
      unit_id: @unit.id,
      room_id: @room.id,
      room_name: "Living Room",
      room_type: "living_room"
    )
    @item = @inspection_room.inspection_items.create!(
      organization: @organization,
      inspection: @inspection,
      item_name: "Window",
      item_type_name: "Windows",
      condition: "good",
      condition_score: 5
    )
  end

  test "creates a valid amendment" do
    amendment = InspectionAmendment.new(
      organization:    @organization,
      inspection:      @inspection,
      inspection_item: @item,
      amended_by:      @user,
      field_name:      "condition",
      original_value:  "good",
      amended_value:   "fair",
      reason:          "Crack spotted after closer inspection"
    )
    assert amendment.valid?, amendment.errors.full_messages.inspect
    assert amendment.save
  end

  test "requires field_name and amended_value" do
    amendment = InspectionAmendment.new(
      organization: @organization, inspection: @inspection,
      inspection_item: @item, amended_by: @user
    )
    assert_not amendment.valid?
    assert amendment.errors[:field_name].any?
    assert amendment.errors[:amended_value].any?
  end

  test "amendment is associated to item and inspection" do
    amendment = InspectionAmendment.create!(
      organization: @organization, inspection: @inspection,
      inspection_item: @item, amended_by: @user,
      field_name: "notes", amended_value: "Updated note"
    )
    assert_includes @item.inspection_amendments, amendment
    assert_includes @inspection.inspection_amendments, amendment
  end
end
