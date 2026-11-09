class InspectionPhoto < ApplicationRecord
  include TenantScoped

  belongs_to :inspection
  belongs_to :inspection_room, optional: true
  belongs_to :inspection_item, optional: true

  validates :storage_key, presence: true
  validate  :must_have_parent

  private

  def must_have_parent
    return if inspection_room_id.present? || inspection_item_id.present?

    errors.add(:base, "must belong to an inspection room or inspection item")
  end
end
