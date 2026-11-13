class Party < ApplicationRecord
  include TenantScoped

  has_many :property_ownerships
  has_many :properties, through: :property_ownerships
  has_many :maintenance_requests, foreign_key: :contractor_id
  has_many :maintenance_schedules, foreign_key: :contractor_id

  validates :party_type, :name, presence: true
end