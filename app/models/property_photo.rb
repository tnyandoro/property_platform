class PropertyPhoto < ApplicationRecord
  include TenantScoped
  include Auditable

  VISIBILITIES = %w[internal tenant_visible].freeze
  MAX_PHOTO_SIZE = 10 * 1024 * 1024
  PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze

  belongs_to :property
  belongs_to :uploaded_by, class_name: "User"
  belongs_to :published_by, class_name: "User", optional: true
  has_one_attached :photo

  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :associations_belong_to_organization
  validate :photo_is_a_supported_image
  validate :publication_metadata_is_consistent

  scope :tenant_visible, -> { where(visibility: "tenant_visible") }

  private

  def associations_belong_to_organization
    if property && property.organization_id != organization_id
      errors.add(:property, "must belong to the same organization")
    end
    [uploaded_by, published_by].compact.each do |user|
      errors.add(:base, "users must belong to the same organization") if user.organization_id != organization_id
    end
  end

  def publication_metadata_is_consistent
    return unless visibility == "tenant_visible"

    if published_at.blank? || published_by.blank?
      errors.add(:visibility, "requires a publisher and publication date")
    elsif property && !published_by.authorized_for_property?(property, "publish_tenant_information")
      errors.add(:published_by, "is not authorized to publish tenant property information")
    end
  end

  def photo_is_a_supported_image
    unless photo.attached?
      errors.add(:photo, "must be attached")
      return
    end

    blob = photo.blob
    unless PHOTO_TYPES.include?(blob.content_type)
      errors.add(:photo, "must be a JPEG, PNG, or WebP image")
    end
    errors.add(:photo, "must be 10 MiB or smaller") if blob.byte_size > MAX_PHOTO_SIZE
  end
end
