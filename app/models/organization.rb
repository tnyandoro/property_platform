class Organization < ApplicationRecord
  has_many :users
  has_many :parties
  has_many :properties
  has_many :property_ownerships
  has_many :buildings
  has_many :units
  has_many :rooms
  has_many :property_items
  has_many :property_assignments

  validates :name, presence: true, uniqueness: true
end