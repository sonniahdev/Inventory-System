class AddImageToProducts < ActiveRecord::Migration[8.0]
def change
  add_column :products, :image, :string # This is a placeholder; Active Storage handles attachments
end
end
