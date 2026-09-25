# frozen_string_literal: true

# Products on sale right now across every open shop, for the home page (feature: home_products).
#
# A product can only be bought from a shop within one of its order cycles, and its price includes
# that shop's fees, so each product is listed as an offer: the product together with the shop and
# order cycle it can be bought from. A product sold by several shops is listed once, from the shop
# whose order cycle closes first, and knows how many shops sell it.
#
# Offers can be narrowed to one country of origin, taken from the producer's address.
class HomeProductsService
  Offer = Data.define(:product, :distributor, :order_cycle, :shop_count)

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
  def initialize(limit: DEFAULT_LIMIT, origin: nil)
    @limit = limit
    @origin = origin
  end

  def offers
    all_offers.select { |offer| from_origin?(offer) }.first(@limit)
  end

  # Countries the products on sale come from, those with the most products first.
  def origins
    all_offers.filter_map { |offer| self.class.origin_of(offer.product) }.
      tally.
      sort_by { |country, count| [-count, country.name] }.
      map(&:first)
  end

  private

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
    Exchange.outgoing.
      joins(:order_cycle).merge(OrderCycle.active).
      where(receiver_id: open_shop_ids).
      includes(:order_cycle, :receiver).
      order("order_cycles.orders_close_at ASC, exchanges.id ASC").
      to_a.
      uniq(&:receiver_id).
      first(MAX_SHOPS).
      map { |exchange| [exchange.receiver, exchange.order_cycle] }
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
