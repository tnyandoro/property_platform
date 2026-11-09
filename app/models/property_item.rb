class PropertyItem < ApplicationRecord
  include TenantScoped

  belongs_to :room
  belongs_to :building
  belongs_to :unit
  belongs_to :property
  belongs_to :item_type

  validates :name, presence: true
end