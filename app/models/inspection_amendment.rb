class InspectionAmendment < ApplicationRecord
  include TenantScoped

  belongs_to :inspection
  belongs_to :inspection_item
  belongs_to :amended_by, class_name: "User"

  validates :field_name, :amended_value, presence: true
end
