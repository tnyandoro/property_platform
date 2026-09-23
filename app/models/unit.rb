class Unit < ApplicationRecord
  include TenantScoped

  belongs_to :building
  has_one :property, through: :building
  has_many :rooms

  validates :bedrooms, :bathrooms, numericality: { greater_than_or_equal_to: 0 }
end