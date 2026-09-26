# frozen_string_literal: true

# A product on the home page (feature: home_products), linking to the shop that sells it.
#
# Unlike ProductTileComponent it has no cart controls: the home page belongs to no shop or order
# cycle, so the visitor picks the product here and orders it in the shop.
class HomeProductTileComponent < ViewComponent::Base
  include CountryNameHelper

  NAME_SEPARATOR = " | "

  def initialize(offer:)
    @offer = offer
  end

  def render?
    product.variants.any?
  end

  private

  attr_reader :offer

  delegate :product, :distributor, :order_cycle, to: :offer

  # Straight to the product in the shop, where ProductFocus scrolls to it.
  def shop_path
    helpers.main_app.enterprise_shop_path(distributor, product: product.id)
  end

  def producer_name
    return t("components.home_product_tile.multiple_producers") unless product.single_producer?

    product.producers.first.name
  end

  # Where the product comes from, so a visitor sees at a glance what travelled from afar.
  def origin
    country = HomeProductsService.origin_of(product)
    country_display_name(country) if country
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

  # The pallet this product travels on, when its order cycle tracks pallets.
  def pallet_progress
    return unless product.single_producer?
    return unless OpenFoodNetwork::FeatureToggle.enabled?(:pallet_progress, order_cycle.coordinator)

    OrderCycles::Pallets.new(order_cycle).for_producer(product.producers.first.id)
  end
end
