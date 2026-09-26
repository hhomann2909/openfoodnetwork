# frozen_string_literal: true

module OrderCycles
  # How full a shared pallet of an order cycle is (feature: pallet_progress).
  #
  # Producers far away deliver an order cycle's orders together, on a pallet. Either the whole
  # order cycle shares one pallet (set on the order cycle), or each producer or region has its
  # own (set on incoming exchanges, see OrderCycles::Pallets). A pallet fills with the weight of
  # its producers' variants in the order cycle's complete orders, in kg.
  class PalletProgress
    attr_reader :name, :producer_ids

    # Without producer_ids, the pallet carries the whole order cycle.
    def initialize(order_cycle, name: nil, capacity: nil, minimum_fill_percent: nil,
                   producer_ids: nil)
      @order_cycle = order_cycle
      @name = name
      @capacity = capacity
      @minimum_fill_percent = minimum_fill_percent
      @producer_ids = producer_ids
    end

    def tracked?
      capacity.positive?
    end

    # kg
    def capacity
      (@capacity || order_cycle.preferred_pallet_capacity).to_d
    end

    # kg
    def ordered_weight
      @ordered_weight ||= begin
        line_items = Spree::LineItem.
          joins(:order).
          joins("INNER JOIN spree_variants ON spree_variants.id = spree_line_items.variant_id").
          merge(Spree::Order.complete).
          where(spree_orders: { order_cycle_id: order_cycle.id }).
          where.not(spree_orders: { state: "canceled" })
        if producer_ids
          line_items = line_items.where(spree_variants: { enterprise_id: producer_ids })
        end

        line_items.
          sum(Arel.sql("spree_line_items.quantity * COALESCE(spree_variants.weight, 0)")).
          to_d
      end
    end

    # Share of the capacity ordered, from 0 to 1.
    def fill
      return 0 unless tracked?

      [ordered_weight / capacity, 1].min
    end

    # Share of the capacity needed for the delivery to go ahead, from 0 to 1. Zero means no
    # minimum was set.
    def minimum_fill
      (@minimum_fill_percent || order_cycle.preferred_pallet_minimum_fill).to_i.clamp(0, 100) /
        100.to_d
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

    def carries?(producer_id)
      producer_ids.nil? || producer_ids.include?(producer_id)
    end

    private

    attr_reader :order_cycle
  end
end
