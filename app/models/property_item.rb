class PropertyItem < ApplicationRecord
  include TenantScoped

  belongs_to :room
  has_one :unit, through: :room
  has_one :property, through: :room

  validates :name, :item_type, presence: true
end