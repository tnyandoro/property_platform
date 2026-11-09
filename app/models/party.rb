class Party < ApplicationRecord
  include TenantScoped

  has_many :property_ownerships
  has_many :properties, through: :property_ownerships

  validates :party_type, :name, presence: true
end