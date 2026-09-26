# frozen_string_literal: true

RSpec.describe HomeProductTileComponent, type: :component do
  subject(:render_tile) { render_inline(described_class.new(offer:)) }

  let(:producer) { create(:supplier_enterprise, name: "Finca Ferrer") }
  let(:shop) { build_stubbed(:distributor_enterprise, name: "Hof Homann", permalink: "hof-homann") }
  let(:order_cycle) { build_stubbed(:simple_order_cycle, orders_close_at: 3.days.from_now) }
  let(:offer) { build_offer(build_product([build_variant])) }

  def build_variant(**overrides)
    ViewData::Variant.new(
      id: 1, on_demand: true, on_hand: 0, display_name: "", name_to_display: "Oranges",
      unit_to_display: "10kg", price: 30, price_with_fees: 32,
      display_price_with_fees: "$32.00", unit_price: UnitPrice.new(build_stubbed(:variant)),
      display_unit_price: "$3.20", enterprise: producer, producer:,
      product: ViewData::SimpleProduct.new(id: 1, name: "Oranges")
    ).with(**overrides)
  end

  def build_product(variants)
    ViewData::Product.new(id: 1, name: "Oranges", description: nil, image: nil,
                          images: Spree::Image.none, variant_images: Spree::Image.none,
                          properties_including_inherited: [], variants:)
  end

  def build_offer(product, shop_count: 1)
    HomeProductsService::Offer.new(product:, distributor: shop, order_cycle:, shop_count:)
  end

  it "links straight to the product in the shop that sells it" do
    render_tile

    expect(page).to have_link href: "/hof-homann/shop?product=1"
    expect(page).to have_selector ".home-product-cta", text: "Order at Hof Homann"
  end

  it "names the producer and the country the product comes from" do
    render_tile

    expect(page).to have_selector ".producer", text: "Finca Ferrer"
    expect(page).to have_selector ".origin", text: producer.address.country.name
  end

  it "shows the product with its unit and its price including fees" do
    render_tile

    expect(page).to have_selector ".product-name", text: "Oranges | 10kg"
    expect(page).to have_selector ".price", text: "$32.00"
  end

  it "starts from the cheapest price when there are several variants" do
    product = build_product([
                              build_variant(id: 1, price_with_fees: 40,
                                            display_price_with_fees: "$40.00"),
                              build_variant(id: 2, price_with_fees: 18,
                                            display_price_with_fees: "$18.00")
                            ])
    render_inline(described_class.new(offer: build_offer(product)))

    expect(page).to have_selector ".prices", text: "from"
    expect(page).to have_selector ".price", text: "$18.00"
    expect(page).to have_selector ".product-name", text: "Oranges"
  end

  it "renders nothing without variants" do
    render_inline(described_class.new(offer: build_offer(build_product([]))))

    expect(page).not_to have_selector ".home-product"
  end
end
