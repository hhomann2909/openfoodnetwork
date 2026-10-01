# frozen_string_literal: true

# Products on sale right now across every open shop, for the home page (feature: home_products).
#
# A product can only be bought from a shop within one of its order cycles, and its price includes
# that shop's fees, so each product is listed as an offer: the product together with the shop and
# order cycle it can be bought from. A product sold by several shops is listed once, from the shop
# whose order cycle closes first, and knows how many shops sell it.
#
# Prices and stock depend on the shop, so the home page lists the products of one pick-up point
# (hub) at a time: the one asked for, else the visitor's current shop, else the one closing
# first. Offers can be narrowed to one country of origin, taken from the producer's address.
class HomeProductsService # rubocop:disable Metrics/ClassLength
  Offer = Data.define(:product, :distributor, :order_cycle, :shop_count)
  # An open shop with the order cycle it sells in and when orders can be picked up there.
  Hub = Data.define(:enterprise, :order_cycle, :pickup_time)
  # Figures for the home page hero, from the same offers.
  Stats = Data.define(:producer_count, :country_count, :shop_count, :item_cost_share,
                      :closes_at)

  DEFAULT_LIMIT = 12
  # Each shop costs a few queries, so only the shops closing soonest are asked for products.
  MAX_SHOPS = 20
  PRODUCTS_PER_SHOP = 12

  # The country a product comes from, or nil when its producers differ or have no country.
  def self.origin_of(product)
    return unless product.single_producer?

    product.producers.first.address&.country
  end

  # origin: ISO code of a country, e.g. "ES", to list only products from there.
  # hub: permalink of the pick-up point asked for; preferred_hub_id: the visitor's current shop.
  def initialize(limit: DEFAULT_LIMIT, origin: nil, hub: nil, preferred_hub_id: nil)
    @limit = limit
    @origin = origin
    @hub_permalink = hub
    @preferred_hub_id = preferred_hub_id
  end

  # Open pick-up points, closing soonest first.
  def hubs
    @hubs ||= shop_exchanges.map do |exchange|
      Hub.new(enterprise: exchange.receiver, order_cycle: exchange.order_cycle,
              pickup_time: exchange.pickup_time.presence)
    end
  end

  # The pick-up point the products are shown for.
  def hub
    @hub ||= hubs.find { |candidate| candidate.enterprise.permalink == @hub_permalink } ||
             hubs.find { |candidate| candidate.enterprise.id == @preferred_hub_id } ||
             hubs.first
  end

  # When nothing is open: when the next order cycle of a public shop opens, if one is planned.
  def next_opens_at
    OrderCycle.upcoming.joins(:exchanges).merge(Exchange.outgoing).
      where(exchanges: { receiver_id: open_shop_ids }).
      minimum(:orders_open_at)
  end

  def offers
    hub_offers.select { |offer| from_origin?(offer) }.first(@limit)
  end

  # Countries the hub's products come from, those with the most products first.
  def origins
    hub_offers.filter_map { |offer| self.class.origin_of(offer.product) }.
      tally.
      sort_by { |country, count| [-count, country.name] }.
      map(&:first)
  end

  def stats
    products = all_offers.map(&:product)
    Stats.new(
      producer_count: products.flat_map(&:producers).map(&:id).uniq.size,
      country_count: origins.size,
      shop_count: shops_with_order_cycle.size,
      item_cost_share:,
      closes_at: all_offers.map { |offer| offer.order_cycle.orders_close_at }.min
    )
  end

  private

  # Average share of the price that is the item cost, what the producer asks for.
  def item_cost_share
    shares = all_offers.flat_map { |offer| offer.product.variants }.filter_map do |variant|
      with_fees = variant.price_with_fees.to_d
      variant.price.to_d / with_fees if with_fees.positive?
    end
    return if shares.empty?

    shares.sum / shares.size
  end

  # Everything the chosen hub sells, each product knowing in how many open shops it is sold.
  def hub_offers
    @hub_offers ||= if hub
                      products_for(hub.enterprise, hub.order_cycle).map do |product|
                        Offer.new(product:, distributor: hub.enterprise,
                                  order_cycle: hub.order_cycle,
                                  shop_count: shop_counts.fetch(product.id, 1))
                      end
                    else
                      []
                    end
  end

  def shop_counts
    @shop_counts ||= all_offers.to_h { |offer| [offer.product.id, offer.shop_count] }
  end

  def all_offers
    @all_offers ||= begin
      candidates = shops_with_order_cycle.flat_map do |shop, order_cycle|
        products_for(shop, order_cycle).map { |product| [product, shop, order_cycle] }
      end

      # group_by keeps insertion order, and shops come soonest closing first.
      candidates.group_by { |product, _shop, _order_cycle| product.id }.values.map do |sellers|
        product, shop, order_cycle = sellers.first
        Offer.new(product:, distributor: shop, order_cycle:, shop_count: sellers.size)
      end
    end
  end

  def from_origin?(offer)
    return true if @origin.blank?

    self.class.origin_of(offer.product)&.iso == @origin
  end

  # Pairs each open shop with its order cycle closing soonest, most urgent shops first.
  def shops_with_order_cycle
    @shops_with_order_cycle ||= shop_exchanges.map do |exchange|
      [exchange.receiver, exchange.order_cycle]
    end
  end

  # The outgoing exchange of each open shop's order cycle closing soonest.
  def shop_exchanges
    @shop_exchanges ||= Exchange.outgoing.
      joins(:order_cycle).merge(OrderCycle.active).
      where(receiver_id: open_shop_ids).
      includes(:order_cycle, receiver: [:address, :logo_attachment]).
      order("order_cycles.orders_close_at ASC, exchanges.id ASC").
      to_a.
      uniq(&:receiver_id).
      first(MAX_SHOPS)
  end

  # Shops anyone can buy from: listed publicly, ready for checkout and not behind a login.
  def open_shop_ids
    Enterprise.activated.visible.is_distributor.ready_for_checkout.
      where(require_login: false).
      reselect("enterprises.id")
  end

  def products_for(shop, order_cycle)
    ProductsRenderer.new(
      shop,
      order_cycle,
      nil,
      { page: 1, per_page: PRODUCTS_PER_SHOP },
      inventory_enabled: OpenFoodNetwork::FeatureToggle.enabled?(:inventory, shop),
      variant_tag_enabled: OpenFoodNetwork::FeatureToggle.enabled?(:variant_tag, shop)
    ).products_view.select { |product| product.variants.any? }
  end
end
