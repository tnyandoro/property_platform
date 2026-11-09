class Inspection < ApplicationRecord
  include TenantScoped
  include Auditable

  belongs_to :property
  belongs_to :inspector, class_name: "User"
  has_many :inspection_rooms,      inverse_of: :inspection, dependent: :destroy
  has_many :inspection_items,      inverse_of: :inspection, dependent: :destroy
  has_many :inspection_amendments, dependent: :destroy
  has_many :inspection_photos,     dependent: :destroy

  validates :inspection_type, :status, presence: true

  def locked?
    locked_at.present?
  end
end