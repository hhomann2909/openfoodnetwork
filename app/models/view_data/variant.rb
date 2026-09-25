# frozen_string_literal: true

# This represent a read only Variant value object, to be used in the view.
ViewData::Variant = Data.define(:id, :on_demand, :on_hand, :display_name, :name_to_display,
                                :unit_to_display, :price, :price_with_fees,
                                :display_price_with_fees, :unit_price, :display_unit_price,
                                :enterprise, :producer, :product, :fees) do
  # `fees` lists the variant's ViewData::Fee items. It defaults to none for views built without
  # an enterprise fee calculator.
  def initialize(fees: [], **)
    super
  end
end
