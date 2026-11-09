class AddCoverPhotoToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :cover_photo_url, :string
  end
end
