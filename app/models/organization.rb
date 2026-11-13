class Organization < ApplicationRecord
  has_many :users
  has_many :parties
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
  has_many :damage_assessments
  has_many :documents
  has_many :audit_logs

  validates :name, presence: true, uniqueness: true
end