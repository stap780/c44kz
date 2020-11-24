class AddColumnQuantity2ToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :quantity2, :integer
  end
end
