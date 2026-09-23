class InspectionItem < ApplicationRecord
  include TenantScoped

  belongs_to :inspection, inverse_of: :inspection_items
  belongs_to :inspection_room, inverse_of: :inspection_items
  belongs_to :property_item, optional: true

  validates :item_name, :item_type_name, :condition, :condition_score, presence: true
  validates :condition_score, inclusion: { in: 1..5 }
end