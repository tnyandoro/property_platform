class PropertyOwnership < ApplicationRecord
  include TenantScoped

  belongs_to :property
  belongs_to :party

  validates :start_date, presence: true
end