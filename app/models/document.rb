class Document < ApplicationRecord
  include TenantScoped

  belongs_to :uploaded_by, class_name: "User"

  # loose parent references (not enforced as FKs to keep it flexible)
  belongs_to :property,           optional: true
  belongs_to :lease,              optional: true
  belongs_to :inspection,         optional: true
  belongs_to :maintenance_request, optional: true
  belongs_to :damage_assessment,  optional: true
  belongs_to :property_ownership, optional: true

  validates :title, :storage_key, :document_type, presence: true
  validate  :must_have_parent
  validate  :ownership_must_match_property_and_organization

  def download_url
    ActiveStorage::Blob.find_by(key: storage_key)&.url(expires_in: 1.hour)
  end

  private

  def must_have_parent
    parents = [property_id, lease_id, inspection_id, maintenance_request_id, damage_assessment_id, property_ownership_id]
    return if parents.any?(&:present?)

    errors.add(:base, "must be attached to a property, ownership record, lease, inspection, maintenance request, or damage assessment")
  end

  def ownership_must_match_property_and_organization
    if uploaded_by && uploaded_by.organization_id != organization_id
      errors.add(:uploaded_by, "must belong to the same organization")
    end
    if property && property.organization_id != organization_id
      errors.add(:property, "must belong to the same organization")
    end

    return unless property_ownership

    if property_ownership.organization_id != organization_id
      errors.add(:property_ownership, "must belong to the same organization")
    end
    if property_id.present? && property_ownership.property_id != property_id
      errors.add(:property_ownership, "must belong to the same property")
    end
  end

end
