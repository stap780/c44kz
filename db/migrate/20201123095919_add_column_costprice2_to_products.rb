class AddColumnCostprice2ToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :costprice2, :decimal
  end
end
