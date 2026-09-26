# frozen_string_literal: true

RSpec.describe OrderCycles::PalletProgress do
  subject(:progress) { described_class.new(order_cycle) }

  let(:distributor) { create(:distributor_enterprise) }
  let(:order_cycle) { create(:simple_order_cycle, distributors: [distributor]) }
  let(:oranges) { create(:variant).tap { |variant| variant.update_column(:weight, 16) } }

  def order(quantity:, variant: oranges, state: "complete", completed: true)
    order = create(:order, distributor:, order_cycle:)
    create(:line_item, order:, variant:, quantity:)
    order.update_columns(state:, completed_at: completed ? Time.zone.now : nil)
    order
  end

  before do
    order_cycle.update!(preferred_pallet_capacity: 80, preferred_pallet_minimum_fill: 80)
  end

  it "adds up the weight of complete orders in kg" do
    order(quantity: 2)
    order(quantity: 1)

    expect(progress.ordered_weight).to eq 48
    expect(progress.fill).to eq 48.to_d / 80
  end

  it "leaves out carts and cancelled orders" do
    order(quantity: 3, state: "cart", completed: false)
    order(quantity: 2, state: "canceled")

    expect(progress.ordered_weight).to eq 0
  end

  it "leaves out orders from other order cycles" do
    other = order(quantity: 3)
    other.update_columns(order_cycle_id: create(:simple_order_cycle).id)

    expect(progress.ordered_weight).to eq 0
  end

  it "counts variants without a weight as nothing" do
    weightless = create(:variant).tap { |variant| variant.update_column(:weight, nil) }
    order(quantity: 3, variant: weightless)

    expect(progress.ordered_weight).to eq 0
  end

  it "says how much is missing until the delivery is confirmed" do
    order(quantity: 3)

    expect(progress).not_to be_confirmed
    expect(progress.weight_to_confirm).to eq 16
  end

  it "confirms the delivery once the minimum is reached" do
    order(quantity: 4)

    expect(progress).to be_confirmed
    expect(progress.weight_to_confirm).to eq 0
  end

  it "never fills beyond the capacity" do
    order(quantity: 4)
    order(quantity: 3)

    expect(progress.fill).to eq 1
  end

  it "counts only its producers' products when it carries some of them" do
    order(quantity: 2)
    other = create(:supplier_enterprise)
    mozzarella = create(:product, enterprise_id: other.id).variants.first
    mozzarella.update_column(:weight, 1)
    order(quantity: 3, variant: mozzarella)

    pallet = described_class.new(order_cycle, capacity: 240, producer_ids: [other.id])
    expect(pallet.ordered_weight).to eq 3
    expect(pallet.capacity).to eq 240
    expect(pallet).to be_carries(other.id)
    expect(pallet).not_to be_carries(oranges.enterprise_id)
  end

  it "isn't tracked without a capacity" do
    order_cycle.update!(preferred_pallet_capacity: 0)

    expect(progress).not_to be_tracked
    expect(progress.fill).to eq 0
  end

  it "never confirms without a minimum" do
    order_cycle.update!(preferred_pallet_minimum_fill: 0)
    order(quantity: 4)

    expect(progress).not_to be_minimum
    expect(progress).not_to be_confirmed
  end
end
