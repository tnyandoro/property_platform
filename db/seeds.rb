organization = Organization.find_or_create_by!(name: "Acme Property Group")

user = organization.users.find_or_initialize_by(email: "admin@acme.example")
user.assign_attributes(
	first_name: "Avery",
	last_name: "Admin",
	password: ENV.fetch("SEED_USER_PASSWORD", "password123")
)
user.save!

property = organization.properties.find_or_create_by!(name: "Acme House") do |record|
	record.assign_attributes(
		property_type: "residential",
		property_subtype: "single_family",
		year_established: 2018,
		land_size: 850,
		building_size: 180,
		original_value: 450_000,
		current_value: 525_000,
		address_line_1: "1 Example Street",
		suburb: "Central",
		city: "Cape Town",
		province: "Western Cape",
		postal_code: "8001",
		country: "South Africa",
		condition: "good",
		description: "Sample property for local development and API testing."
	)
end

property.property_assignments.find_or_create_by!(user: user) do |assignment|
	assignment.assign_attributes(
		organization: organization,
		assignment_type: "manager",
		starts_at: Time.current
	)
end

building = property.buildings.find_or_create_by!(name: "Main House") do |record|
	record.assign_attributes(
		organization: organization,
		building_type: "residential",
		description: "Primary residential building."
	)
end

unit = building.units.find_or_create_by!(unit_number: "1") do |record|
	record.assign_attributes(
		organization: organization,
		property: property,
		name: "Main Residence",
		unit_type: "residential",
		bedrooms: 3,
		bathrooms: 2,
		floor_area: 180,
		condition: "good"
	)
end

room_specs = [
	["Living Room", "living_room", 32],
	["Kitchen", "kitchen", 16],
	["Patio", "patio", 18],
	["Bathroom 1", "bathroom", 8],
	["Bathroom 2", "bathroom", 6],
	["Bedroom 1", "bedroom", 16],
	["Bedroom 2", "bedroom", 14],
	["Bedroom 3", "bedroom", 12]
]

rooms = room_specs.to_h do |room_name, room_type, floor_area|
	room = unit.rooms.find_or_create_by!(room_name: room_name) do |record|
		record.assign_attributes(
			organization: organization,
			building: building,
			property: property,
			room_type: room_type,
			floor_area: floor_area
		)
	end
	[room_name, room]
end

room = rooms.fetch("Living Room")

item_type = organization.item_types.find_or_create_by!(name: "Furniture") do |record|
	record.category = "furniture"
end

room.property_items.find_or_create_by!(name: "Sofa") do |item|
	item.assign_attributes(
		organization: organization,
		building: building,
		unit: unit,
		property: property,
		item_type: item_type,
		description: "Three-seat fabric sofa",
		installed_at: Date.new(2022, 6, 1)
	)
end

inspection = organization.inspections.find_or_initialize_by(
	property: property,
	inspection_type: "routine",
	scheduled_on: Date.new(2026, 10, 1)
)
inspection.assign_attributes(
	inspector: user,
	status: "draft",
	notes: "Initial sample inspection for local development."
)
inspection.save!

checklist = {
	"Living Room" => ["Windows", "Door", "Light fixtures", "Wall sockets", "Curtain rails", "Ceiling", "Sofa"],
	"Kitchen" => ["Windows", "Door", "Light fixtures", "Wall sockets", "Ceiling", "Taps", "Sink", "Cabinetry", "Countertops", "Stove", "Oven", "Extractor fan"],
	"Patio" => ["Door", "Windows", "Light fixtures", "Wall sockets", "Ceiling", "Flooring", "Drainage"],
	"Bathroom 1" => ["Door", "Windows", "Light fixtures", "Wall sockets", "Ceiling", "Taps", "Shower", "Toilet", "Basin", "Flooring", "Ventilation"],
	"Bathroom 2" => ["Door", "Windows", "Light fixtures", "Wall sockets", "Ceiling", "Taps", "Shower", "Toilet", "Basin", "Flooring", "Ventilation"],
	"Bedroom 1" => ["Windows", "Door", "Closets", "Light fixtures", "Wall sockets", "Curtain rails", "Ceiling", "Flooring"],
	"Bedroom 2" => ["Windows", "Door", "Closets", "Light fixtures", "Wall sockets", "Curtain rails", "Ceiling", "Flooring"],
	"Bedroom 3" => ["Windows", "Door", "Closets", "Light fixtures", "Wall sockets", "Curtain rails", "Ceiling", "Flooring"]
}

seed_snapshot = lambda do |target_inspection|
	checklist.each do |room_name, item_names|
		inspection_room = target_inspection.inspection_rooms.find_or_initialize_by(room_id: rooms.fetch(room_name).id)
		inspection_room.assign_attributes(
			organization: organization,
			property_id: property.id,
			building_id: building.id,
			unit_id: unit.id,
			room_name: room_name,
			room_type: rooms.fetch(room_name).room_type,
			floor_number: rooms.fetch(room_name).floor_number,
			notes: "#{room_name} snapshot ready for review."
		)
		inspection_room.save!

		item_names.each do |item_name|
			property_item = room_name == "Living Room" && item_name == "Sofa" ? rooms.fetch(room_name).property_items.find_by(name: item_name) : nil
			inspection_item = inspection_room.inspection_items.find_or_initialize_by(item_name: item_name)
			inspection_item.assign_attributes(
				organization: organization,
				inspection: target_inspection,
				property_item: property_item,
				item_type_name: item_name,
				condition: "good",
				condition_score: 5,
				responsibility: "landlord",
				notes: "No visible defects recorded."
			)
			inspection_item.save!
		end
	end
end

seed_snapshot.call(inspection)

move_in_inspection = organization.inspections.find_or_initialize_by(
	property: property,
	inspection_type: "move_in",
	scheduled_on: Date.new(2026, 10, 15)
)
move_in_inspection.assign_attributes(
	inspector: user,
	status: "draft",
	notes: "Move-in inspection covering every room and fixture."
)
move_in_inspection.save!
seed_snapshot.call(move_in_inspection)

property.update!(cached_total_units: property.units.count, cached_total_bedrooms: property.units.sum(:bedrooms))

puts "Seeded #{organization.name} with user #{user.email}, property #{property.name}, and move-in inspection #{move_in_inspection.id}."
