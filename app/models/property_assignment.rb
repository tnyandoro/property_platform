class PropertyAssignment < ApplicationRecord
  include TenantScoped

  belongs_to :property
  belongs_to :user

  validates :assignment_type, :starts_at, presence: true
end