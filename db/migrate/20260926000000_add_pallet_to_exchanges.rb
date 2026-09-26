# frozen_string_literal: true

# A shared pallet per producer or region (feature: pallet_progress): incoming exchanges with the
# same pallet name travel on one pallet of the given capacity.
class AddPalletToExchanges < ActiveRecord::Migration[7.2]
  def change
    add_column :exchanges, :pallet_name, :string
    add_column :exchanges, :pallet_capacity, :decimal, precision: 10, scale: 2, default: 0,
                                                       null: false
    add_column :exchanges, :pallet_minimum_fill, :integer, default: 0, null: false
  end
end
