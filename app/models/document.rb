class Document < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :uploaded_by, class_name: "User"

  # loose parent references (not enforced as FKs to keep it flexible)
  belongs_to :property,           optional: true
  belongs_to :lease,              optional: true
  belongs_to :inspection,         optional: true
  belongs_to :maintenance_request, optional: true
  belongs_to :maintenance_financial_entry, optional: true
  belongs_to :damage_assessment,  optional: true
  belongs_to :property_ownership, optional: true
  belongs_to :published_by, class_name: "User", optional: true

  VISIBILITIES = %w[internal tenant_visible].freeze

  validates :title, :storage_key, :document_type, presence: true
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate  :must_have_parent
  validate  :ownership_must_match_property_and_organization
  validate :maintenance_request_must_match_parent
  validate :publication_metadata_is_consistent

  def download_url
    ActiveStorage::Blob.find_by(key: storage_key)&.url(expires_in: 1.hour)
  end

  private

  def must_have_parent
    parents = [
      property_id, lease_id, inspection_id, maintenance_request_id,
      maintenance_financial_entry_id, damage_assessment_id, property_ownership_id
    ]
    return if parents.any?(&:present?)

    errors.add(:base, "must be attached to a property, ownership record, lease, inspection, maintenance request, or damage assessment")
  end

  def ownership_must_match_property_and_organization
    if uploaded_by && uploaded_by.organization_id != organization_id
      errors.add(:uploaded_by, "must belong to the same organization")
    end

    def publication_metadata_is_consistent
      if published_by && published_by.organization_id != organization_id
        errors.add(:published_by, "must belong to the same organization")
      end
      return unless visibility == "tenant_visible"

      if published_at.blank? || published_by.blank?
        errors.add(:visibility, "requires a publisher and publication date")
        return
      end

      linked_property = property || lease&.property || maintenance_request&.property ||
        inspection&.property || damage_assessment&.property || property_ownership&.property
      if linked_property && linked_property.organization_id == organization_id &&
         !published_by.authorized_for_property?(linked_property, "publish_tenant_information")
        errors.add(:published_by, "is not authorized to share documents for this property")
      end

      linked_records = [lease, inspection, maintenance_request, maintenance_financial_entry,
        damage_assessment, property_ownership].compact
      if linked_records.any? { |record| record.organization_id != organization_id }
        errors.add(:base, "tenant-visible document parents must belong to the same organization")
      end
      parent_property_ids = [
        lease&.property_id,
        inspection&.property_id,
        maintenance_request&.property_id,
        maintenance_financial_entry&.maintenance_request&.property_id,
        damage_assessment&.property_id,
        property_ownership&.property_id
      ].compact.uniq
      expected_property_id = property_id || parent_property_ids.first
      if parent_property_ids.length > 1 || (expected_property_id && parent_property_ids.any? { |id| id != expected_property_id })
        errors.add(:base, "tenant-visible document parents must belong to the same property")
      end
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
    linked_request = maintenance_request || maintenance_financial_entry&.maintenance_request
    return unless linked_request

    if linked_request.organization_id != organization_id
      errors.add(:maintenance_request, "must belong to the same organization")
    end
    expected_property_id = property_id || lease&.property_id || inspection&.property_id ||
      damage_assessment&.property_id || property_ownership&.property_id
    if expected_property_id.present? && linked_request.property_id != expected_property_id
      errors.add(:maintenance_request, "must belong to the same property")
    end
    if lease && (lease.organization_id != organization_id || lease.property_id != linked_request.property_id)
      errors.add(:lease, "must belong to the same property and organization")
    end
    if inspection && (inspection.organization_id != organization_id || inspection.property_id != linked_request.property_id)
      errors.add(:inspection, "must belong to the same property and organization")
    end
    if damage_assessment && (damage_assessment.organization_id != organization_id || damage_assessment.property_id != linked_request.property_id)
      errors.add(:damage_assessment, "must belong to the same property and organization")
    end
    if maintenance_financial_entry &&
       (maintenance_financial_entry.organization_id != organization_id ||
        maintenance_financial_entry.maintenance_request_id != linked_request.id)
      errors.add(:maintenance_financial_entry, "must belong to the linked maintenance request and organization")
    end
  end

end
