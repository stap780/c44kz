class AddColumnPriceproptToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :pricepropt, :integer
  end
end
