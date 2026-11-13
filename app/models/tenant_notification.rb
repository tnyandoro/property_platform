class TenantNotification < ApplicationRecord
  include TenantScoped
  include Auditable

  TYPES = %w[lease_expiring lease_renewal_proposal lease_extension_request maintenance_request_update].freeze
  SOURCES = %w[lease lease_renewal_proposal lease_extension_request maintenance_request_update].freeze

  belongs_to :tenant_profile
  belongs_to :lease, optional: true
  belongs_to :lease_renewal_proposal, optional: true
  belongs_to :lease_extension_request, optional: true
  belongs_to :maintenance_request_update, optional: true

  validates :notification_type, :title, :body, presence: true
  validates :notification_type, inclusion: { in: TYPES }
  validate :exactly_one_source
  validate :source_is_visible_to_tenant

  scope :unread, -> { where(read_at: nil) }

  private

  def exactly_one_source
    count = SOURCES.count { |source| public_send("#{source}_id").present? }
    errors.add(:base, "must have exactly one tenant notification source") unless count == 1
  end

  def source_is_visible_to_tenant
    return unless tenant_profile

    source = lease || lease_renewal_proposal || lease_extension_request || maintenance_request_update
    if tenant_profile.organization_id != organization_id
      errors.add(:tenant_profile, "must belong to the same organization")
    end
    return unless source

    errors.add(:base, "source must belong to the same organization") if source.organization_id != organization_id
    unless notification_type_matches_source?(source) && source_is_for_tenant?(source)
      errors.add(:base, "source must be relevant to this tenant and notification type")
    end
  end

  def notification_type_matches_source?(source)
    expected_type = {
      "Lease" => "lease_expiring",
      "LeaseRenewalProposal" => "lease_renewal_proposal",
      "LeaseExtensionRequest" => "lease_extension_request",
      "MaintenanceRequestUpdate" => "maintenance_request_update"
    }[source.class.name]
    notification_type == expected_type
  end

  def source_is_for_tenant?(source)
    case source
    when Lease
      source.tenant_id == tenant_profile.party_id
    when LeaseRenewalProposal
      source.lease&.tenant_id == tenant_profile.party_id
    when LeaseExtensionRequest
      source.tenant_profile_id == tenant_profile_id
    when MaintenanceRequestUpdate
      request = source.maintenance_request
      source.status == "published" && request&.lease&.tenant_id == tenant_profile.party_id
    else
      false
    end
  end
end
