require "test_helper"

class LeasesTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Lease Registry")
    @manager = @organization.users.create!(
      email: "lease.manager@example.com",
      first_name: "Lena",
      last_name: "Manager",
      password: "password123"
    )
    @property = @organization.properties.create!(name: "Lease Property", property_type: "residential")
    @building = @property.buildings.create!(organization: @organization, name: "Main")
    @unit = @building.units.create!(
      organization: @organization,
      property: @property,
      unit_number: "1",
      unit_type: "residential"
    )
    @property.property_assignments.create!(
      organization: @organization,
      user: @manager,
      assignment_type: "manager",
      starts_at: 1.hour.ago
    )
    authenticate_as(@manager)
  end

  test "uploads a PDF with the lease period and tenant details" do
    upload = pdf_upload

    assert_difference ["Lease.count", "Party.count", "ActiveStorage::Blob.count"], 1 do
      post leases_path,
           params: {
             lease: {
               unit_id: @unit.id,
               tenant: { name: "Taylor Tenant", party_type: "individual" },
               start_date: "2026-01-01",
               end_date: "2026-12-31",
               lease_type: "fixed_term",
               monthly_rent: "1500",
               rent_currency: "USD"
             },
             lease_pdf: upload
           },
           headers: @auth_headers
    end

    assert_response :created
    lease = Lease.order(:created_at).last
    assert_equal Date.new(2026, 1, 1), lease.start_date
    assert_equal Date.new(2026, 12, 31), lease.end_date
    assert_equal "Taylor Tenant", lease.tenant.name
    assert lease.lease_pdf.attached?
    assert_equal "application/pdf", lease.lease_pdf.blob.content_type
    assert JSON.parse(response.body).fetch("pdf_url").present?
  end

  test "rejects a file that is not a PDF without creating a lease" do
    upload = Rack::Test::UploadedFile.new(
      StringIO.new("not a PDF"),
      "application/pdf",
      true,
      original_filename: "lease.pdf"
    )

    assert_no_difference ["Lease.count", "Party.count", "ActiveStorage::Blob.count"] do
      post leases_path,
           params: {
             lease: valid_lease_params,
             lease_pdf: upload
           },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
  end

  test "rejects an invalid lease date range and purges the uploaded blob" do
    assert_no_difference ["Lease.count", "Party.count", "ActiveStorage::Blob.count"] do
      post leases_path,
           params: {
             lease: valid_lease_params.merge(start_date: "2026-12-31", end_date: "2026-01-01"),
             lease_pdf: pdf_upload
           },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors").join, "cannot be before"
  end

  test "only an active property manager can upload a lease" do
    staff = @organization.users.create!(
      email: "lease.staff@example.com",
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

    assert_no_difference ["Lease.count", "ActiveStorage::Blob.count"] do
      post leases_path,
           params: { lease: valid_lease_params, lease_pdf: pdf_upload },
           headers: @auth_headers
    end

    assert_response :forbidden
  end

  test "lists lease PDFs only for the assigned property" do
    post leases_path,
         params: { lease: valid_lease_params, lease_pdf: pdf_upload },
         headers: @auth_headers
    assert_response :created

    get leases_path, headers: @auth_headers

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 1, payload.length
    assert_equal @unit.id, payload.first.fetch("unit_id")
    assert payload.first.fetch("pdf_url").present?
  end

  private

  def leases_path
    "/api/v1/properties/#{@property.id}/leases"
  end

  def valid_lease_params
    {
      unit_id: @unit.id,
      tenant: { name: "Taylor Tenant", party_type: "individual" },
      start_date: "2026-01-01",
      end_date: "2026-12-31",
      lease_type: "fixed_term",
      monthly_rent: "1500",
      rent_currency: "USD"
    }
  end

  def pdf_upload
    Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-1.4 test lease"),
      "application/pdf",
      true,
      original_filename: "lease-agreement.pdf"
    )
  end

  def authenticate_as(user)
    post api_v1_login_path, params: { email: user.email, password: "password123" }, as: :json
    assert_response :created
    @auth_headers = { "Authorization" => "Bearer #{JSON.parse(response.body).fetch('token')}" }
  end
end
