# frozen_string_literal: true

# Shows customers where the price of a variant goes: the item cost, and each fee added by the
# enterprises in the order cycle, such as transport, packing or the shop's own fee.
#
# Takes a ViewData::Variant built with its fees (see ProductsRenderer).
class PriceBreakdownComponent < ViewComponent::Base
  def initialize(variant:, show_variant_name: false)
    @variant = variant
    @show_variant_name = show_variant_name
  end

  # Without fees the price is the item cost, so there is nothing to break down.
  def render?
    variant.fees.any?
  end

  private

  attr_reader :variant, :show_variant_name

  def variant_name
    [variant.name_to_display, variant.unit_to_display].compact_blank.join(" ")
  end

  def item_cost
    money(variant.price)
  end

  def money(amount)
    Spree::Money.new(amount).to_s
  end

  # Each part of the price with its share of the total, for the bar. Discounts (negative fees)
  # can't be drawn as a share, so the bar is left out when there are any.
  def segments
    return [] if variant.fees.any? { |fee| fee.amount.negative? } || total.zero?

    [[t("item_cost"), variant.price]] + variant.fees.map { |fee| [fee.name, fee.amount] }
  end

  def share_of_total(amount)
    (amount.to_d / total * 100).round(1).to_f
  end

  def item_cost_share
    helpers.number_to_percentage(share_of_total(variant.price), precision: 0)
  end

  def total
    variant.price_with_fees.to_d
  end
end
