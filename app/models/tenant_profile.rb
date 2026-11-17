class TenantProfile < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :party_account
  has_one :user, through: :party_account
  has_one :party, through: :party_account
  has_one_attached :profile_photo
  has_many :lease_extension_requests, dependent: :restrict_with_error
  has_many :tenant_notifications, dependent: :restrict_with_error

  delegate :user_id, :party_id, to: :party_account

  MAX_PROFILE_PHOTO_SIZE = 10 * 1024 * 1024
  PROFILE_PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze

  validates :tenant_reference, uniqueness: { scope: :organization_id }, allow_nil: true
  validate :party_account_is_verified
  validate :profile_photo_is_a_supported_image

  private

  def party_account_is_verified
    return unless party_account

    if party_account.organization_id != organization_id
      errors.add(:party_account, "must belong to the same organization")
    end
    errors.add(:party_account, "must be verified") unless party_account.verified?

    conflicting_profile = party_account.user&.tenant_profiles
      &.where(organization_id: organization_id)
      &.where.not(id: id)
      &.exists?
    errors.add(:party_account, "already has a tenant profile") if conflicting_profile
  end

  def profile_photo_is_a_supported_image
    return unless profile_photo.attached?

    blob = profile_photo.blob
    unless PROFILE_PHOTO_TYPES.include?(blob.content_type)
      errors.add(:profile_photo, "must be a JPEG, PNG, or WebP image")
    end
    errors.add(:profile_photo, "must be 10 MiB or smaller") if blob.byte_size > MAX_PROFILE_PHOTO_SIZE
  end
end
