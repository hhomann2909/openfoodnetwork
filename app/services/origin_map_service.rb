# frozen_string_literal: true

# Data for the origin map (feature: origin_map): where food comes from, where it can be picked
# up, and the routes between them in open order cycles.
#
# Producers and shops are the public, activated enterprises with coordinates. A route joins a
# producer to a shop when an open order cycle carries the producer's products to that shop, so
# the map shows orders travelling together from the farm to the pick-up point.
class OriginMapService
  include Rails.application.routes.url_helpers
  include CountryNameHelper

  PRODUCTS_PER_PRODUCER = 4

  def as_json(*)
    { producers:, shops:, routes: }
  end

  private

  def producers
    located(Enterprise.is_primary_producer).map do |producer|
      point(producer, :producer).merge(products: product_names.fetch(producer.id, []))
    end
  end

  def shops
    located(Enterprise.is_distributor).map do |shop|
      point(shop, :shop).merge(shop_url: enterprise_shop_path(shop),
                               open: open_shop_ids.include?(shop.id))
    end
  end

  def routes
    open_exchanges.group_by(&:order_cycle).flat_map do |order_cycle, exchanges|
      order_cycle_routes(order_cycle, exchanges)
    end.uniq { |route| [route[:from], route[:to]] }
  end

  # Every located producer supplying the order cycle, to every located shop it delivers to.
  def order_cycle_routes(order_cycle, exchanges)
    producer_ids = exchanges.select(&:incoming).map(&:sender_id) & located_ids.to_a
    shop_ids = exchanges.reject(&:incoming).map(&:receiver_id) & located_ids.to_a

    producer_ids.product(shop_ids).map do |producer_id, shop_id|
      route(order_cycle, producer_id, shop_id)
    end
  end

  def route(order_cycle, producer_id, shop_id)
    progress = pallet_progress(order_cycle)
    {
      from: producer_id, to: shop_id, order_cycle: order_cycle.name,
      closes_at: order_cycle.orders_close_at.iso8601,
      pallet_fill: progress&.tracked? ? (progress.fill * 100).round.to_i : nil,
      pallet_confirmed: progress&.confirmed? || false,
    }
  end

  def point(enterprise, kind)
    address = enterprise.address
    {
      id: enterprise.id, kind:, name: enterprise.name,
      place: [address.city, country_display_name(address.country)].compact_blank.join(", "),
      country: address.country.iso,
      country_name: country_display_name(address.country),
      lat: address.latitude, lng: address.longitude,
      logo: logo_url(enterprise),
    }
  end

  def logo_url(enterprise)
    return unless enterprise.logo.attached?

    enterprise.logo_url(:thumb)
  rescue StandardError
    nil
  end

  def located(scope)
    scope.activated.visible.includes(address: :country).
      where(id: located_ids).
      with_attached_logo.
      order(:name)
  end

  def located_ids
    @located_ids ||= Enterprise.joins(:address).
      where("spree_addresses.latitude IS NOT NULL AND spree_addresses.longitude IS NOT NULL").
      pluck(:id).to_set
  end

  def open_exchanges
    @open_exchanges ||= Exchange.joins(:order_cycle).merge(OrderCycle.active).
      includes(:order_cycle).to_a
  end

  def open_shop_ids
    @open_shop_ids ||= open_exchanges.reject(&:incoming).to_set(&:receiver_id)
  end

  # Names of the products each producer has on sale in open order cycles.
  def product_names
    @product_names ||= Spree::Variant.
      joins(:exchanges, :product).
      merge(Exchange.outgoing).
      where(exchanges: { id: open_exchanges.map(&:id) }).
      distinct.
      pluck(:enterprise_id, "spree_products.name").
      group_by(&:first).
      transform_values { |pairs| pairs.map(&:last).uniq.sort.first(PRODUCTS_PER_PRODUCER) }
  end

  def pallet_progress(order_cycle)
    return unless OpenFoodNetwork::FeatureToggle.enabled?(:pallet_progress, order_cycle.coordinator)

    OrderCycles::PalletProgress.new(order_cycle)
  end
end
