class Inspection < ApplicationRecord
  include TenantScoped

  belongs_to :property
  belongs_to :inspector, class_name: "User"
  has_many :inspection_rooms, inverse_of: :inspection
  has_many :inspection_items, inverse_of: :inspection

  validates :inspection_type, :status, presence: true
end