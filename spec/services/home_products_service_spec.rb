# frozen_string_literal: true

RSpec.describe HomeProductsService do
  subject(:offers) { described_class.new.offers }

  let(:producer) { create(:supplier_enterprise) }
  let(:shop) { create(:distributor_enterprise, with_payment_and_shipping: true) }
  let(:oranges) { create(:product, name: "Oranges", enterprise_id: producer.id) }
  let(:lemons) { create(:product, name: "Lemons", enterprise_id: producer.id) }

  def open_order_cycle(distributors:, variants:, closes_in: 1.week)
    create(:simple_order_cycle, suppliers: [producer], distributors:, variants:,
                                orders_open_at: 1.day.ago, orders_close_at: closes_in.from_now)
  end

  it "lists products on sale in an open shop, with the shop and order cycle to buy them from" do
    order_cycle = open_order_cycle(distributors: [shop], variants: [oranges.variants.first])

    expect(offers.map { |offer| offer.product.name }).to eq ["Oranges"]
    expect(offers.first.distributor).to eq shop
    expect(offers.first.order_cycle).to eq order_cycle
    expect(offers.first.shop_count).to eq 1
  end

  it "includes the shop's fees in the price" do
    open_order_cycle(distributors: [shop], variants: [oranges.variants.first])

    expect(offers.first.product.variants.first.price_with_fees).to be_present
  end

  it "leaves out products from closed order cycles" do
    create(:closed_order_cycle, suppliers: [producer], distributors: [shop],
                                variants: [oranges.variants.first])

    expect(offers).to be_empty
  end

  it "leaves out shops that aren't ready for checkout" do
    unready_shop = create(:distributor_enterprise)
    open_order_cycle(distributors: [unready_shop], variants: [oranges.variants.first])

    expect(offers).to be_empty
  end

  it "leaves out shops that require customers to log in" do
    shop.update!(require_login: true)
    open_order_cycle(distributors: [shop], variants: [oranges.variants.first])

    expect(offers).to be_empty
  end

  it "leaves out shops that aren't listed publicly" do
    shop.update!(visible: "only_through_links")
    open_order_cycle(distributors: [shop], variants: [oranges.variants.first])

    expect(offers).to be_empty
  end

  it "leaves out products that are out of stock" do
    sold_out = create(:product, enterprise_id: producer.id, on_hand: 0)
    open_order_cycle(distributors: [shop], variants: [sold_out.variants.first])

    expect(offers).to be_empty
  end

  describe "a product sold by several shops" do
    let(:other_shop) { create(:distributor_enterprise, with_payment_and_shipping: true) }

    it "is listed once, from the shop whose order cycle closes first" do
      open_order_cycle(distributors: [shop], variants: [oranges.variants.first],
                       closes_in: 2.weeks)
      open_order_cycle(distributors: [other_shop], variants: [oranges.variants.first],
                       closes_in: 2.days)

      expect(offers.size).to eq 1
      expect(offers.first.distributor).to eq other_shop
      expect(offers.first.shop_count).to eq 2
    end
  end

  it "lists offers from the soonest closing order cycle first" do
    other_shop = create(:distributor_enterprise, with_payment_and_shipping: true)
    open_order_cycle(distributors: [shop], variants: [oranges.variants.first],
                     closes_in: 2.weeks)
    open_order_cycle(distributors: [other_shop], variants: [lemons.variants.first],
                     closes_in: 2.days)

    expect(offers.map { |offer| offer.product.name }).to eq ["Lemons", "Oranges"]
  end

  describe "country of origin" do
    let(:italian_producer) { create(:supplier_enterprise) }
    let(:mozzarella) { create(:product, name: "Mozzarella", enterprise_id: italian_producer.id) }
    let(:spain) { Spree::Country.find_by(iso: "ES") || create(:country, iso: "ES", name: "Spain") }
    let(:italy) { Spree::Country.find_by(iso: "IT") || create(:country, iso: "IT", name: "Italy") }

    before do
      producer.address.update_columns(country_id: spain.id)
      italian_producer.address.update_columns(country_id: italy.id)
      open_order_cycle(distributors: [shop], variants: [oranges.variants.first,
                                                        lemons.variants.first,
                                                        mozzarella.variants.first])
    end

    it "lists the countries products come from, most products first" do
      expect(described_class.new.origins).to eq [spain, italy]
    end

    it "narrows offers to one country" do
      offers = described_class.new(origin: "IT").offers

      expect(offers.map { |offer| offer.product.name }).to eq ["Mozzarella"]
    end

    it "still knows all countries while narrowed to one" do
      expect(described_class.new(origin: "IT").origins).to eq [spain, italy]
    end

    it "finds the country of a product from its producer's address" do
      product = described_class.new(origin: "ES").offers.first.product

      expect(described_class.origin_of(product)).to eq spain
    end
  end

  describe "#stats" do
    it "sums up what is on sale for the home page hero" do
      order_cycle = open_order_cycle(distributors: [shop],
                                     variants: [oranges.variants.first, lemons.variants.first])
      order_cycle.coordinator_fees << create(:enterprise_fee, amount: 10)

      stats = described_class.new.stats
      price = oranges.variants.first.price.to_d
      expect(stats.producer_count).to eq 1
      expect(stats.shop_count).to eq 1
      expect(stats.closes_at).to eq order_cycle.orders_close_at
      expect(stats.item_cost_share).to be_within(0.001).of(price / (price + 10))
    end

    it "has no figures when nothing is on sale" do
      stats = described_class.new.stats

      expect(stats.producer_count).to eq 0
      expect(stats.item_cost_share).to be_nil
      expect(stats.closes_at).to be_nil
    end
  end

  it "stops at the limit" do
    open_order_cycle(distributors: [shop],
                     variants: [oranges.variants.first, lemons.variants.first])

    expect(described_class.new(limit: 1).offers.size).to eq 1
  end
end
