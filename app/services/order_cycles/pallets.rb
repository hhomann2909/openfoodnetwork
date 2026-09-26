# frozen_string_literal: true

module OrderCycles
  # The shared pallets of an order cycle (feature: pallet_progress).
  #
  # Coordinators set pallets on incoming exchanges: each producer with a capacity gets its own
  # pallet, and producers with the same pallet name (a region, say "Valencia") share one, sized
  # by the largest capacity and minimum set among them. Without any, the order cycle's own
  # pallet (if set) carries everything.
  class Pallets
    def initialize(order_cycle)
      @order_cycle = order_cycle
    end

    def all
      @all ||= exchange_pallets.presence || order_cycle_pallet
    end

    # The pallet carrying a producer's products, if any.
    def for_producer(producer_id)
      all.find { |pallet| pallet.carries?(producer_id) }
    end

    private

    attr_reader :order_cycle

    def exchange_pallets
      pallet_exchanges.group_by { |exchange| group_key(exchange) }.values.map do |exchanges|
        PalletProgress.new(
          order_cycle,
          name: exchanges.first.pallet_name.presence || exchanges.first.sender.name,
          capacity: exchanges.map(&:pallet_capacity).max,
          minimum_fill_percent: exchanges.map(&:pallet_minimum_fill).max,
          producer_ids: exchanges.map(&:sender_id)
        )
      end
    end

    def pallet_exchanges
      order_cycle.exchanges.incoming.includes(:sender).
        where("exchanges.pallet_capacity > 0").
        order(:id)
    end

    def group_key(exchange)
      exchange.pallet_name.presence&.strip&.downcase || "exchange-#{exchange.id}"
    end

    def order_cycle_pallet
      pallet = PalletProgress.new(order_cycle)
      pallet.tracked? ? [pallet] : []
    end
  end
end
