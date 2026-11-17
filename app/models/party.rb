class Party < ApplicationRecord
  include TenantScoped

  has_many :property_ownerships
  has_many :properties, through: :property_ownerships
  has_many :party_accounts, dependent: :restrict_with_error
  has_many :users, through: :party_accounts
  has_many :maintenance_requests, foreign_key: :contractor_id
  has_many :maintenance_schedules, foreign_key: :contractor_id
  has_many :maintenance_financial_entries
  has_many :maintenance_cost_allocations
  has_many :tenant_invitations, foreign_key: :tenant_party_id, dependent: :restrict_with_error

  validates :party_type, :name, presence: true
end