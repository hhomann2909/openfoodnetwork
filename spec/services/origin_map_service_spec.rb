# frozen_string_literal: true

RSpec.describe OriginMapService do
  subject(:data) { described_class.new.as_json }

  let(:producer) { create(:supplier_enterprise, name: "Finca Ferrer") }
  let(:shop) { create(:distributor_enterprise, name: "Hof Homann") }
  let(:oranges) { create(:product, name: "Oranges", enterprise_id: producer.id) }

  def locate(enterprise, latitude, longitude)
    enterprise.address.update_columns(latitude:, longitude:)
  end

  before do
    locate(producer, 39.15, -0.43)
    locate(shop, 52.05, 7.35)
  end

  it "lists located producers with what they have on sale" do
    create(:simple_order_cycle, suppliers: [producer], distributors: [shop],
                                variants: [oranges.variants.first])

    point = data[:producers].sole
    expect(point).to include(id: producer.id, kind: :producer, name: "Finca Ferrer",
                             lat: 39.15, lng: -0.43, products: ["Oranges"])
  end

  it "lists located shops, open or not, with their shop link" do
    point = data[:shops].sole

    expect(point).to include(id: shop.id, kind: :shop, open: false,
                             shop_url: "/#{shop.permalink}/shop")
  end

  it "leaves out enterprises without coordinates" do
    create(:distributor_enterprise, name: "Nowhere")

    expect(data[:shops].pluck(:name)).to eq ["Hof Homann"]
  end

  it "leaves out enterprises that aren't public" do
    shop.update!(visible: "only_through_links")

    expect(data[:shops]).to be_empty
  end

  it "joins a producer to the shops an open order cycle delivers to" do
    order_cycle = create(:simple_order_cycle, suppliers: [producer], distributors: [shop],
                                              variants: [oranges.variants.first])

    expect(data[:routes]).to eq [{
      from: producer.id, to: shop.id, order_cycle: order_cycle.name,
      closes_at: order_cycle.orders_close_at.iso8601, pallet_fill: nil, pallet_confirmed: false
    }]
    expect(data[:shops].sole[:open]).to be true
  end

  it "has no routes for closed order cycles" do
    create(:closed_order_cycle, suppliers: [producer], distributors: [shop],
                                variants: [oranges.variants.first])

    expect(data[:routes]).to be_empty
  end

  it "adds the pallet's fill to routes", feature: :pallet_progress do
    order_cycle = create(:simple_order_cycle, suppliers: [producer], distributors: [shop],
                                              variants: [oranges.variants.first])
    order_cycle.update!(preferred_pallet_capacity: 800)

    expect(data[:routes].sole[:pallet_fill]).to eq 0
  end
end
