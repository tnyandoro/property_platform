class PropertyOwnership < ApplicationRecord
  include TenantScoped

  belongs_to :property
  belongs_to :party

  validates :start_date, :ownership_percentage, presence: true
end