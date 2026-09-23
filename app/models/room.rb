class Room < ApplicationRecord
  include TenantScoped

  belongs_to :unit
  belongs_to :building
  belongs_to :property
  has_many :property_items

  validates :room_name, :room_type, presence: true
end