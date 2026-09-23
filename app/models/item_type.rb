class ItemType < ApplicationRecord
  include TenantScoped

  has_many :property_items

  validates :name, presence: true, uniqueness: { scope: :organization_id }
end