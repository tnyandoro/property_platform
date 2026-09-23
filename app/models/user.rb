class User < ApplicationRecord
  include TenantScoped

  has_secure_password

  has_many :property_assignments
  has_many :properties, through: :property_assignments

  validates :email, presence: true, uniqueness: { scope: :organization_id }
  validates :first_name, :last_name, presence: true

  normalizes :email, with: ->(email) { email.strip.downcase }
end