class PlatformAdministratorGrant < ApplicationRecord
  belongs_to :user
  belongs_to :granted_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  validates :reason, presence: true
  validate :revocation_metadata_is_consistent

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  private

  def revocation_metadata_is_consistent
    if revoked_at.present? != revoked_by.present?
      errors.add(:revoked_by, "and revocation date must be recorded together")
    end
  end
end
