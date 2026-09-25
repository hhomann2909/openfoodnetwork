# frozen_string_literal: true

# A product on the home page (feature: home_products), linking to the shop that sells it.
#
# Unlike ProductTileComponent it has no cart controls: the home page belongs to no shop or order
# cycle, so the visitor picks the product here and orders it in the shop.
class HomeProductTileComponent < ViewComponent::Base
  NAME_SEPARATOR = " | "

  def initialize(offer:)
    @offer = offer
  end

  def render?
    product.variants.any?
  end

  private

  attr_reader :offer

  delegate :product, :distributor, :order_cycle, :shop_count, to: :offer

  def shop_path
    helpers.main_app.enterprise_shop_path(distributor)
  end

  def producer_name
    return t("components.home_product_tile.multiple_producers") unless product.single_producer?

    product.producers.first.name
  end

  # Where the product comes from, so a visitor sees at a glance what travelled from afar.
  def origin
    return unless product.single_producer?

    product.producers.first.address&.country&.name
  end

  def product_name
    return product.name unless product.single_variant?

    safe_join([product.name, product.variant.unit_to_display].compact_blank, NAME_SEPARATOR)
  end

  def price
    return product.variant.display_price_with_fees if product.single_variant?

    product.cheapest_variant.display_price_with_fees
  end

  def unit_price
    return unless product.single_variant?

    helpers.unit_price_with_unit(product.variant)
  end

  def sold_at
    if shop_count > 1
      t("components.home_product_tile.sold_at_and_more", shop: distributor.name,
                                                         count: shop_count - 1)
    else
      t("components.home_product_tile.sold_at", shop: distributor.name)
    end
  end

  def closes_in
    t("components.home_product_tile.closes_in",
      time: helpers.distance_of_time_in_words_to_now(order_cycle.orders_close_at))
  end
end
