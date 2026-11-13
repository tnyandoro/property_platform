class Organization < ApplicationRecord
  has_many :users
  has_many :parties
  has_many :party_accounts, dependent: :restrict_with_error
  has_many :tenant_profiles, dependent: :restrict_with_error
  has_many :tenant_invitations, dependent: :restrict_with_error
  has_many :lease_renewal_proposals, dependent: :restrict_with_error
  has_many :lease_extension_requests, dependent: :restrict_with_error
  has_many :property_photos, dependent: :restrict_with_error
  has_many :maintenance_request_updates, dependent: :restrict_with_error
  has_many :tenant_notifications, dependent: :restrict_with_error
  has_many :properties
  has_many :property_ownerships
  has_many :buildings
  has_many :units
  has_many :rooms
  has_many :property_items
  has_many :item_types
  has_many :inspections
  has_many :inspection_amendments
  has_many :inspection_photos
  has_many :property_assignments
  has_many :leases
  has_many :maintenance_requests
  has_many :maintenance_schedules
  has_many :maintenance_cost_allocations
  has_many :maintenance_financial_entries
  has_many :maintenance_quotes, class_name: "MaintenanceQuote"
  has_many :maintenance_invoices, class_name: "MaintenanceInvoice"
  has_many :maintenance_payments, class_name: "MaintenancePayment"
  has_many :damage_assessments
  has_many :documents
  has_many :audit_logs

  validates :name, presence: true, uniqueness: true
end