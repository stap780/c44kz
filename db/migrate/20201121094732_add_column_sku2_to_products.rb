class AddColumnSku2ToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :sku2, :string
  end
end
