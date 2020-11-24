class AddColumnQuantity1ToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :quantity1, :integer
  end
end
