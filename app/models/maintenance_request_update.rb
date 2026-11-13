class MaintenanceRequestUpdate < ApplicationRecord
  include TenantScoped
  include Auditable

  UPDATE_TYPES = %w[status update scheduled_visit completion].freeze
  STATUSES = %w[draft published withdrawn].freeze

  belongs_to :maintenance_request
  belongs_to :author, class_name: "User"
  belongs_to :published_by, class_name: "User", optional: true

  validates :body, :update_type, :status, presence: true
  validates :update_type, inclusion: { in: UPDATE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validate :associations_belong_to_organization
  validate :scheduled_end_is_not_before_start
  validate :publication_metadata_is_consistent

  scope :published, -> { where(status: "published") }

  private

  def associations_belong_to_organization
    if maintenance_request && maintenance_request.organization_id != organization_id
      errors.add(:maintenance_request, "must belong to the same organization")
    end
    [author, published_by].compact.each do |user|
      errors.add(:base, "users must belong to the same organization") if user.organization_id != organization_id
    end
  end

  def scheduled_end_is_not_before_start
    return if scheduled_start_at.blank? || scheduled_end_at.blank? || scheduled_end_at >= scheduled_start_at

    errors.add(:scheduled_end_at, "cannot be before the scheduled start")
  end

  def publication_metadata_is_consistent
    return unless status == "published"

    if published_at.blank? || published_by.blank?
      errors.add(:status, "requires a publisher and publication date")
    elsif maintenance_request && !published_by.authorized_for_property?(
      maintenance_request.property,
      "publish_tenant_information"
    )
      errors.add(:published_by, "is not authorized to publish maintenance updates for this property")
    end
  end
end
