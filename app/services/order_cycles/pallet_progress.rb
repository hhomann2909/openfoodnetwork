# frozen_string_literal: true

module OrderCycles
  # How full the shared pallet of an order cycle is (feature: pallet_progress).
  #
  # Producers far away deliver an order cycle's orders together, on one pallet. The coordinator
  # sets how many kg fit on it and how full it must be for the delivery to go ahead. The pallet
  # fills with the weight of the variants in the order cycle's complete orders, in kg.
  class PalletProgress
    def initialize(order_cycle)
      @order_cycle = order_cycle
    end

    def tracked?
      capacity.positive?
    end

    # kg
    def capacity
      order_cycle.preferred_pallet_capacity.to_d
    end

    # kg
    def ordered_weight
      @ordered_weight ||= Spree::LineItem.
        joins(:order).
        joins("INNER JOIN spree_variants ON spree_variants.id = spree_line_items.variant_id").
        merge(Spree::Order.complete).
        where(spree_orders: { order_cycle_id: order_cycle.id }).
        where.not(spree_orders: { state: "canceled" }).
        sum(Arel.sql("spree_line_items.quantity * COALESCE(spree_variants.weight, 0)")).
        to_d
    end

    # Share of the capacity ordered, from 0 to 1.
    def fill
      return 0 unless tracked?

      [ordered_weight / capacity, 1].min
    end

    # Share of the capacity needed for the delivery to go ahead, from 0 to 1. Zero means the
    # coordinator set no minimum.
    def minimum_fill
      order_cycle.preferred_pallet_minimum_fill.clamp(0, 100) / 100.to_d
    end

    def minimum?
      minimum_fill.positive?
    end

    def confirmed?
      minimum? && ordered_weight >= capacity * minimum_fill
    end

    # kg still to be ordered before the delivery is confirmed.
    def weight_to_confirm
      [(capacity * minimum_fill) - ordered_weight, 0].max
    end

    private

    attr_reader :order_cycle
  end
end
