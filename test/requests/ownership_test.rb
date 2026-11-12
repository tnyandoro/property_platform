require "test_helper"

class OwnershipTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Registry Group")
    @manager = @organization.users.create!(
      email: "registry.manager@example.com",
      first_name: "Mara",
      last_name: "Manager",
      password: "password123"
    )
    @property = @organization.properties.create!(
      name: "Registry House",
      property_type: "residential",
      original_value: 150_000,
      current_value: 220_000
    )
    @property.property_assignments.create!(
      organization: @organization,
      user: @manager,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    @party = @organization.parties.create!(name: "Current Owner", party_type: "individual")
    authenticate_as(@manager)
  end

  test "creates a retrospective ownership record without requiring a purchase price" do
    assert_difference "PropertyOwnership.count", 1 do
      post ownership_path, params: {
        property_ownership: {
          party_id: @party.id,
          ownership_percentage: 100,
          start_date: "1998-04-12",
          transfer_type: "inheritance",
          notes: "Recorded from family history."
        }
      }, headers: @auth_headers, as: :json
    end

    assert_response :created
    payload = JSON.parse(response.body)
    assert_equal "1998-04-12", payload.fetch("start_date")
    assert_nil payload["transfer_value"]
    assert_equal "unverified", payload.fetch("verification_status")
    assert_equal "historical", payload.fetch("effective_status")
  end

  test "creates a new party and ownership record in the same request" do
    assert_difference ["Party.count", "PropertyOwnership.count"], 1 do
      post ownership_path, params: {
        property_ownership: {
          party: { name: "Family Trust", party_type: "trust" },
          ownership_percentage: 100,
          start_date: Date.current.to_s,
          transfer_type: "family_transfer"
        }
      }, headers: @auth_headers, as: :json
    end

    assert_response :created
    assert_equal "Family Trust", JSON.parse(response.body).dig("party", "name")
  end

  test "lists parties only from the authenticated organization" do
    other_organization = Organization.create!(name: "Unrelated Registry")
    other_organization.parties.create!(name: "Private Party", party_type: "company")

    get "/api/v1/parties", headers: @auth_headers

    assert_response :success
    parties = JSON.parse(response.body)
    assert_equal [@party.id], parties.pluck("id")
  end

  test "rejects party records from another organization" do
    other_organization = Organization.create!(name: "Other Registry")
    other_party = other_organization.parties.create!(name: "External Owner", party_type: "company")

    assert_no_difference "PropertyOwnership.count" do
      post ownership_path, params: {
        property_ownership: {
          party_id: other_party.id,
          ownership_percentage: 100,
          start_date: Date.current.to_s
        }
      }, headers: @auth_headers, as: :json
    end

    assert_response :not_found
  end

  test "prevents overlapping ownership shares from exceeding one hundred percent" do
    @property.property_ownerships.create!(
      organization: @organization,
      party: @party,
      ownership_percentage: 70,
      start_date: "2020-01-01"
    )
    another_party = @organization.parties.create!(name: "Second Owner", party_type: "individual")

    assert_no_difference "PropertyOwnership.count" do
      post ownership_path, params: {
        property_ownership: {
          party_id: another_party.id,
          ownership_percentage: 40,
          start_date: "2022-01-01"
        }
      }, headers: @auth_headers, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors").join, "exceed 100%"
  end

  test "records a transfer atomically and keeps joint owners as separate records" do
    previous_owner = @organization.parties.create!(name: "Previous Owner", party_type: "company")
    previous_record = @property.property_ownerships.create!(
      organization: @organization,
      party: previous_owner,
      ownership_percentage: 100,
      start_date: "2010-01-01"
    )
    co_owner = @organization.parties.create!(name: "Co-owner", party_type: "individual")
    effective_on = Date.current

    assert_difference "PropertyOwnership.count", 2 do
      post transfer_path, params: {
        transfer: {
          effective_on: effective_on.to_s,
          transfer_type: "sale_purchase",
          transfer_value: "250000",
          valuation_at_transfer: "275000",
          currency: "ZWG",
          transfer_reference: "DEED-2026-04",
          conveyancer: "Registry Legal",
          incoming_owners: [
            { party_id: @party.id, ownership_percentage: 60 },
            { party_id: co_owner.id, ownership_percentage: 40 }
          ]
        }
      }, headers: @auth_headers, as: :json
    end

    assert_response :created
    assert_equal effective_on, previous_record.reload.end_date
    records = @property.property_ownerships.active_on(effective_on)
    assert_equal [40.to_d, 60.to_d], records.order(:ownership_percentage).pluck(:ownership_percentage)
    assert_equal "ZWG", records.first.currency
    assert_equal 250_000.to_d, records.first.transfer_value
    assert_equal 275_000.to_d, records.first.valuation_at_transfer
  end

  test "edits an ownership record without changing its history dates" do
    record = @property.property_ownerships.create!(
      organization: @organization,
      party: @party,
      ownership_percentage: 100,
      start_date: "2001-02-03",
      transfer_type: "inheritance"
    )

    patch ownership_record_path(record), params: {
      property_ownership: {
        notes: "Confirmed from archived records.",
        transfer_reference: "ARCHIVE-17"
      }
    }, headers: @auth_headers, as: :json

    assert_response :success
    assert_equal Date.new(2001, 2, 3), record.reload.start_date
    assert_equal "Confirmed from archived records.", record.notes
    assert_equal "ARCHIVE-17", record.transfer_reference
  end

  test "closes an ownership record while retaining it in the history" do
    record = @property.property_ownerships.create!(
      organization: @organization,
      party: @party,
      ownership_percentage: 100,
      start_date: "2010-01-01"
    )

    post "#{ownership_record_path(record)}/close",
         params: { end_date: Date.current.to_s },
         headers: @auth_headers,
         as: :json

    assert_response :success
    assert_equal Date.current, record.reload.end_date
    assert_equal "historical", record.effective_status
    assert_includes @property.property_ownerships.pluck(:id), record.id
  end

  test "future-dated transfers do not replace the current owner early" do
    previous_record = @property.property_ownerships.create!(
      organization: @organization,
      party: @party,
      ownership_percentage: 100,
      start_date: "2010-01-01"
    )
    incoming = @organization.parties.create!(name: "Future Owner", party_type: "individual")
    effective_on = Date.current + 30.days

    post transfer_path, params: {
      transfer: {
        effective_on: effective_on.to_s,
        incoming_owners: [{ party_id: incoming.id, ownership_percentage: 100 }]
      }
    }, headers: @auth_headers, as: :json

    assert_response :created
    assert_equal effective_on, previous_record.reload.end_date
    assert_equal "current", previous_record.effective_status
    assert_equal "upcoming", @property.property_ownerships.find_by!(party: incoming).effective_status
  end

  test "only an active property manager can verify ownership" do
    record = @property.property_ownerships.create!(
      organization: @organization,
      party: @party,
      ownership_percentage: 100,
      start_date: "2020-01-01"
    )
    staff = @organization.users.create!(
      email: "registry.staff@example.com",
      first_name: "Sam",
      last_name: "Staff",
      password: "password123"
    )
    @property.property_assignments.create!(
      organization: @organization,
      user: staff,
      assignment_type: "inspector",
      starts_at: 1.hour.ago
    )
    authenticate_as(staff)

    patch ownership_record_path(record), params: {
      property_ownership: { verification_status: "verified" }
    }, headers: @auth_headers, as: :json

    assert_response :forbidden
    assert_nil record.reload.verified_at

    authenticate_as(@manager)
    patch ownership_record_path(record), params: {
      property_ownership: { verification_status: "verified" }
    }, headers: @auth_headers, as: :json

    assert_response :success
    assert_equal @manager, record.reload.verified_by
    assert_not_nil record.verified_at
  end

  test "ownership documents are stored against the ownership record and listed securely" do
    record = @property.property_ownerships.create!(
      organization: @organization,
      party: @party,
      ownership_percentage: 100,
      start_date: "2020-01-01"
    )
    upload = Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-1.4 test document"),
      "application/pdf",
      true,
      original_filename: "title-deed.pdf"
    )

    assert_difference "Document.count", 1 do
      post ownership_documents_path(record),
           params: { file: upload, document_type: "title_deed", title: "Title deed" },
           headers: @auth_headers
    end

    assert_response :created
    document = record.documents.sole
    assert_equal @property, document.property
    assert_equal @organization, document.organization

    get ownership_documents_path(record), headers: @auth_headers
    assert_response :success
    assert_equal document.id, JSON.parse(response.body).first.fetch("id")
  end

  private

  def ownership_path
    "/api/v1/properties/#{@property.id}/ownership"
  end

  def transfer_path
    "#{ownership_path}/transfers"
  end

  def ownership_record_path(record)
    "#{ownership_path}/#{record.id}"
  end

  def ownership_documents_path(record)
    "#{ownership_record_path(record)}/documents"
  end

  def authenticate_as(user)
    post api_v1_login_path, params: { email: user.email, password: "password123" }, as: :json
    assert_response :created
    @auth_headers = { "Authorization" => "Bearer #{JSON.parse(response.body).fetch('token')}" }
  end
end
