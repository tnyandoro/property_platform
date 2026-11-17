class AccessTokenRevocation < ApplicationRecord
  belongs_to :user

  validates :token_id, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }
end
