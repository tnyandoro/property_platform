class Property < ApplicationRecord
  include TenantScoped

  has_many :buildings
  has_many :units, through: :buildings
  has_many :rooms, through: :units
  has_many :property_items, through: :rooms
  has_many :property_ownerships
  has_many :property_assignments
  has_many :assigned_users, through: :property_assignments, source: :user

  validates :name, :property_type, presence: true
  validates :cached_total_units, :cached_total_bedrooms,
            numericality: { greater_than_or_equal_to: 0 }
end