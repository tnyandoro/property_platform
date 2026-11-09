class InspectionSnapshotBuilder
  CHECKLIST = {
    "living_room" => %w[Windows Door Light fixtures Wall sockets Curtain rails Ceiling Sofa],
    "kitchen" => %w[Windows Door Light fixtures Wall sockets Ceiling Taps Sink Cabinetry Countertops Stove Oven Extractor fan],
    "patio" => %w[Door Windows Light fixtures Wall sockets Ceiling Flooring Drainage],
    "bathroom" => %w[Windows Door Light fixtures Wall sockets Ceiling Taps Shower Toilet Basin Flooring Ventilation],
    "bedroom" => %w[Windows Door Closets Light fixtures Wall sockets Curtain rails Ceiling Flooring]
  }.freeze

  def self.ensure!(inspection)
    new(inspection).ensure!
  end

  def initialize(inspection)
    @inspection = inspection
    @property = inspection.property
  end

  def ensure!
    return @inspection if @inspection.inspection_rooms.exists?

    @property.rooms.find_each do |room|
      snapshot_room = @inspection.inspection_rooms.create!(
        organization_id: @inspection.organization_id,
        property_id: @property.id,
        building_id: room.building_id,
        unit_id: room.unit_id,
        room_id: room.id,
        room_name: room.room_name,
        room_type: room.room_type,
        floor_number: room.floor_number,
        notes: "#{room.room_name} snapshot ready for review."
      )

      checklist_for(room).each do |item_name|
        property_item = room.property_items.find_by(name: item_name)
        snapshot_room.inspection_items.create!(
          organization_id: @inspection.organization_id,
          inspection: @inspection,
          property_item: property_item,
          item_name: item_name,
          item_type_name: item_name,
          condition: "good",
          condition_score: 5,
          responsibility: "landlord",
          notes: "No visible defects recorded."
        )
      end
    end

    @inspection
  end

  private

  def checklist_for(room)
    CHECKLIST.fetch(room.room_type, CHECKLIST.fetch("living_room"))
  end
end