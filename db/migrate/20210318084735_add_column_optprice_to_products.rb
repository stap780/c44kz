class AddColumnOptpriceToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :optprice, :decimal
  end
end
