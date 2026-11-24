class MakeUserOrganizationOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :organization_id, true
  end
end
