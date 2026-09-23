class Room < ApplicationRecord
  include TenantScoped

  belongs_to :unit
  has_one :building, through: :unit
  has_one :property, through: :unit
  has_many :property_items

  validates :name, :room_type, presence: true
end