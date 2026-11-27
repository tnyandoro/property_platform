class InspectionPhoto < ApplicationRecord
  include TenantScoped

  belongs_to :inspection
  belongs_to :inspection_room, optional: true
  belongs_to :inspection_item, optional: true

  validates :storage_key, presence: true
  validate :must_have_parent
  validate :parents_belong_to_inspection
  validate :item_belongs_to_room

  private

  def must_have_parent
    return if inspection_room_id.present? || inspection_item_id.present?

    errors.add(:base, "must belong to an inspection room or inspection item")
  end

  def parents_belong_to_inspection
    return unless inspection

    if inspection_room && (
      inspection_room.inspection_id != inspection_id ||
      inspection_room.organization_id != organization_id
    )
      errors.add(:inspection_room, "must belong to the same inspection and organization")
    end

    if inspection_item && (
      inspection_item.inspection_id != inspection_id ||
      inspection_item.organization_id != organization_id
    )
      errors.add(:inspection_item, "must belong to the same inspection and organization")
    end
  end

  def item_belongs_to_room
    return unless inspection_room && inspection_item

    if inspection_item.inspection_room_id != inspection_room_id
      errors.add(:inspection_item, "must belong to the selected room")
    end
  end
end
