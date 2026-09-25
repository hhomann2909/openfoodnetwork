# frozen_string_literal: true

RSpec.describe PriceBreakdownComponent, type: :component do
  let(:producer) { build_stubbed(:supplier_enterprise) }
  let(:freight) {
    ViewData::Fee.new(name: "Pallet freight", enterprise_name: "Fair Europe Coop",
                      fee_type: "transport", amount: BigDecimal("3.60"))
  }
  let(:shop_fee) {
    ViewData::Fee.new(name: "Pick-up point", enterprise_name: "Hof Homann",
                      fee_type: "sales", amount: BigDecimal("2.70"))
  }

  def build_variant(fees:, price: BigDecimal("23.70"))
    price_with_fees = price + fees.sum(&:amount)
    ViewData::Variant.new(
      id: 1, on_demand: true, on_hand: 0, display_name: "", name_to_display: "Oranges",
      unit_to_display: "10kg", price:, price_with_fees:,
      display_price_with_fees: Spree::Money.new(price_with_fees).to_s,
      unit_price: UnitPrice.new(build_stubbed(:variant)), display_unit_price: "",
      enterprise: producer, producer:,
      product: ViewData::SimpleProduct.new(id: 1, name: "Oranges"), fees:
    )
  end

  it "lists the item cost, each fee with its enterprise, and the total" do
    render_inline(described_class.new(variant: build_variant(fees: [freight, shop_fee])))

    expect(page).to have_selector ".item-cost dd", text: "$23.70"
    expect(page).to have_selector ".fee dt", text: "Pallet freight"
    expect(page).to have_selector ".fee dt small", text: "Fair Europe Coop"
    expect(page).to have_selector ".fee dd", text: "$3.60"
    expect(page).to have_selector ".fee dd", text: "$2.70"
    expect(page).to have_selector ".total dd", text: "$30.00"
  end

  it "says how much of the price is the item cost" do
    render_inline(described_class.new(variant: build_variant(fees: [freight, shop_fee])))

    expect(page).to have_selector ".item-cost-share", text: "79%"
  end

  it "draws each part of the price to scale" do
    render_inline(described_class.new(variant: build_variant(fees: [freight, shop_fee])))

    widths = page.all(".price-breakdown-bar .segment").map { |segment| segment[:style] }
    expect(widths).to eq ["width: 79.0%", "width: 12.0%", "width: 9.0%"]
  end

  it "leaves out the bar when a fee is a discount" do
    discount = freight.with(name: "Member discount", amount: BigDecimal("-1.00"))
    render_inline(described_class.new(variant: build_variant(fees: [discount])))

    expect(page).to have_selector ".fee dd", text: "1.00"
    expect(page).not_to have_selector ".price-breakdown-bar"
    expect(page).not_to have_selector ".item-cost-share"
  end

  it "names the variant when asked to" do
    render_inline(described_class.new(variant: build_variant(fees: [freight]),
                                      show_variant_name: true))

    expect(page).to have_selector ".variant-name", text: "Oranges 10kg"
  end

  it "renders nothing when there are no fees" do
    render_inline(described_class.new(variant: build_variant(fees: [])))

    expect(page).not_to have_selector ".price-breakdown"
  end
end
