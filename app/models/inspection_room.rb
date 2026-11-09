class InspectionRoom < ApplicationRecord
  include TenantScoped

  belongs_to :inspection,     inverse_of: :inspection_rooms
  has_many   :inspection_items,  inverse_of: :inspection_room, dependent: :destroy
  has_many   :inspection_photos, dependent: :destroy

  validates :room_name, :room_type, presence: true
end