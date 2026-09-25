# frozen_string_literal: true

# Products on sale right now across every open shop, for the home page (feature: home_products).
#
# A product can only be bought from a shop within one of its order cycles, and its price includes
# that shop's fees, so each product is listed as an offer: the product together with the shop and
# order cycle it can be bought from. A product sold by several shops is listed once, from the shop
# whose order cycle closes first, and knows how many shops sell it.
class HomeProductsService
  Offer = Data.define(:product, :distributor, :order_cycle, :shop_count)

  DEFAULT_LIMIT = 12
  # Each shop costs a few queries, so only the shops closing soonest are asked for products.
  MAX_SHOPS = 20
  PRODUCTS_PER_SHOP = 12

  def initialize(limit: DEFAULT_LIMIT)
    @limit = limit
  end

  def offers
    candidates = shops_with_order_cycle.flat_map do |shop, order_cycle|
      products_for(shop, order_cycle).map { |product| [product, shop, order_cycle] }
    end

    # group_by keeps insertion order, and shops come soonest closing first.
    candidates.group_by { |product, _shop, _order_cycle| product.id }.values.map do |sellers|
      product, shop, order_cycle = sellers.first
      Offer.new(product:, distributor: shop, order_cycle:, shop_count: sellers.size)
    end.first(@limit)
  end

  private

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
