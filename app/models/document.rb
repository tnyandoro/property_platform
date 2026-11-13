class Document < ApplicationRecord
  include TenantScoped
  include Auditable

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
  validate :maintenance_request_must_match_parent

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

  def maintenance_request_must_match_parent
    return unless maintenance_request

    if maintenance_request.organization_id != organization_id
      errors.add(:maintenance_request, "must belong to the same organization")
    end
    expected_property_id = property_id || lease&.property_id || inspection&.property_id || damage_assessment&.property_id
    if expected_property_id.present? && maintenance_request.property_id != expected_property_id
      errors.add(:maintenance_request, "must belong to the same property")
    end
    if lease && (lease.organization_id != organization_id || lease.property_id != maintenance_request.property_id)
      errors.add(:lease, "must belong to the same property and organization")
    end
    if inspection && (inspection.organization_id != organization_id || inspection.property_id != maintenance_request.property_id)
      errors.add(:inspection, "must belong to the same property and organization")
    end
    if damage_assessment && (damage_assessment.organization_id != organization_id || damage_assessment.property_id != maintenance_request.property_id)
      errors.add(:damage_assessment, "must belong to the same property and organization")
    end
  end

end
