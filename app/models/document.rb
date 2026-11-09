class Document < ApplicationRecord
  include TenantScoped

  belongs_to :uploaded_by, class_name: "User"

  # loose parent references (not enforced as FKs to keep it flexible)
  belongs_to :property,           optional: true
  belongs_to :lease,              optional: true
  belongs_to :inspection,         optional: true
  belongs_to :maintenance_request, optional: true
  belongs_to :damage_assessment,  optional: true

  validates :title, :storage_key, :document_type, presence: true
  validate  :must_have_parent

  private

  def must_have_parent
    parents = [property_id, lease_id, inspection_id, maintenance_request_id, damage_assessment_id]
    return if parents.any?(&:present?)

    errors.add(:base, "must be attached to a property, lease, inspection, maintenance request, or damage assessment")
  end
end
