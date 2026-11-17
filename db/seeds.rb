raise "Demo seed accounts must not be created in production" if Rails.env.production?

seed_password = ENV["SEED_USER_PASSWORD"].presence
raise "Set SEED_USER_PASSWORD before running db:seed" if seed_password.blank?

organization = Organization.find_or_create_by!(name: "Acme Property Group")

user = organization.users.find_or_initialize_by(email: "admin@acme.example")
user.assign_attributes(
	first_name: "Avery",
	last_name: "Admin",
	organization_role: "administrator",
	email_verified_at: Time.current,
	password: seed_password
)
user.save!

admin_membership = organization.organization_memberships.find_or_initialize_by(user: user)
admin_membership.assign_attributes(role: "administrator", status: "active")
admin_membership.save!

staff_users = {
	manager: ["Morgan", "Manager", "manager@acme.example", "manager", %w[invite_tenants propose_lease_renewals publish_tenant_information]],
	agent: ["Alex", "Agent", "agent@acme.example", "agent", %w[invite_tenants propose_lease_renewals]],
	inspector: ["Indigo", "Inspector", "inspector@acme.example", "inspector", []]
}.to_h do |key, (first_name, last_name, email, _assignment_type, _capabilities)|
	staff_user = organization.users.find_or_initialize_by(email: email)
	staff_user.assign_attributes(
		first_name: first_name,
		last_name: last_name,
		organization_role: "member",
		email_verified_at: Time.current,
		password: seed_password
	)
	staff_user.save!

	membership = organization.organization_memberships.find_or_initialize_by(user: staff_user)
	membership.assign_attributes(role: "member", status: "active")
	membership.save!

	[key, staff_user]
end

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

property.property_assignments.find_or_create_by!(user: staff_users.fetch(:manager)) do |assignment|
	assignment.assign_attributes(
		organization: organization,
		assignment_type: "manager",
		capabilities: %w[invite_tenants propose_lease_renewals publish_tenant_information],
		starts_at: Time.current
	)
end

property.property_assignments.find_or_create_by!(user: staff_users.fetch(:agent)) do |assignment|
	assignment.assign_attributes(
		organization: organization,
		assignment_type: "agent",
		capabilities: %w[invite_tenants propose_lease_renewals],
		starts_at: Time.current
	)
end

property.property_assignments.find_or_create_by!(user: staff_users.fetch(:inspector)) do |assignment|
	assignment.assign_attributes(
		organization: organization,
		assignment_type: "inspector",
		starts_at: Time.current
	)
end

previous_owner = organization.parties.find_or_create_by!(name: "Admire Smith", party_type: "individual")
current_owner = organization.parties.find_or_create_by!(name: "Tendai Nyandoro", party_type: "individual")

previous_ownership = property.property_ownerships.find_or_initialize_by(
	organization: organization,
	party: previous_owner,
	start_date: Date.new(2024, 1, 1)
)
previous_ownership.assign_attributes(
	ownership_percentage: 100,
	end_date: Date.new(2025, 1, 1),
	transfer_type: "sale_purchase",
	currency: "USD",
	transfer_value: nil,
	valuation_at_transfer: nil,
	verification_status: "unverified",
	verified_at: nil,
	verified_by: nil,
	notes: "Demonstration ownership history; transaction value not recorded."
)
previous_ownership.save!

current_ownership = property.property_ownerships.find_or_initialize_by(
	organization: organization,
	party: current_owner,
	start_date: Date.new(2025, 1, 1)
)
current_ownership.assign_attributes(
	ownership_percentage: 100,
	end_date: nil,
	transfer_type: "sale_purchase",
	currency: "USD",
	transfer_value: nil,
	valuation_at_transfer: nil,
	verification_status: "verified",
	verified_at: Time.current,
	verified_by: user,
	notes: "Demonstration current ownership; transaction value not recorded."
)
current_ownership.save!

owner_user = User.find_or_initialize_by(email: "owner@acme.example", organization_id: nil)
owner_user.skip_initial_organization_membership = true if owner_user.new_record?
owner_user.assign_attributes(
	first_name: "Tendai",
	last_name: "Nyandoro",
	email_verified_at: Time.current,
	password: seed_password
)
owner_user.save!

owner_party_account = organization.party_accounts.find_or_initialize_by(user: owner_user, party: current_owner)
owner_party_account.assign_attributes(
	status: "verified",
	verified_at: Time.current,
	verified_by: user
)
owner_party_account.save!

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

tenant_party = organization.parties.find_or_create_by!(name: "Taylor Tenant", party_type: "individual")

tenant_user = User.find_or_initialize_by(email: "tenant@acme.example", organization_id: nil)
tenant_user.skip_initial_organization_membership = true if tenant_user.new_record?
tenant_user.assign_attributes(
	first_name: "Taylor",
	last_name: "Tenant",
	email_verified_at: Time.current,
	password: seed_password
)
tenant_user.save!

tenant_party_account = organization.party_accounts.find_or_initialize_by(user: tenant_user, party: tenant_party)
tenant_party_account.assign_attributes(
	status: "verified",
	verified_at: Time.current,
	verified_by: user
)
tenant_party_account.save!

tenant_profile = organization.tenant_profiles.find_or_initialize_by(party_account: tenant_party_account)
tenant_profile.assign_attributes(tenant_reference: "TENANT-ACME-001", phone_number: "+27110000001")
tenant_profile.save!

lease = organization.leases.find_or_initialize_by(
	property: property,
	unit: unit,
	tenant: tenant_party,
	start_date: Date.new(2026, 1, 1)
)
lease.assign_attributes(
	status: "active",
	lease_type: "fixed_term",
	end_date: Date.new(2027, 12, 31),
	signed_date: Date.new(2025, 12, 15),
	monthly_rent: 18_500,
	deposit_amount: 18_500,
	rent_currency: "ZAR",
	notice_period_days: 30,
	terms_summary: "Demonstration fixed-term residential lease."
)
lease.save!

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
	inspector: staff_users.fetch(:inspector),
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
	inspector: staff_users.fetch(:inspector),
	status: "draft",
	notes: "Move-in inspection covering every room and fixture."
)
move_in_inspection.save!
seed_snapshot.call(move_in_inspection)

property.update!(cached_total_units: property.units.count, cached_total_bedrooms: property.units.sum(:bedrooms))

puts <<~OUTPUT
	Seeded #{organization.name} with:
	  Management administrator: admin@acme.example
	  Property manager:          manager@acme.example
	  Property agent:            agent@acme.example
	  Inspector:                 inspector@acme.example
	  Property owner:            owner@acme.example
	  Tenant:                    tenant@acme.example
	  Property:                  #{property.name}
	  Active lease:              #{lease.id}
	  Move-in inspection:        #{move_in_inspection.id}
	All demo accounts use the password supplied through SEED_USER_PASSWORD.
OUTPUT
