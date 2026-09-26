# frozen_string_literal: true

RSpec.describe OrderCycles::Pallets do
  subject(:pallets) { described_class.new(order_cycle) }

  let(:ferrer) { create(:supplier_enterprise, name: "Finca Ferrer") }
  let(:molina) { create(:supplier_enterprise, name: "Huerta Molina") }
  let(:esposito) { create(:supplier_enterprise, name: "Caseificio Esposito") }
  let(:shop) { create(:distributor_enterprise) }
  let(:order_cycle) {
    create(:simple_order_cycle, suppliers: [ferrer, molina, esposito], distributors: [shop])
  }

  def exchange_of(producer)
    order_cycle.exchanges.incoming.find_by!(sender: producer)
  end

  def variant_of(producer, weight:)
    create(:product, enterprise_id: producer.id).variants.first.tap do |variant|
      variant.update_column(:weight, weight)
    end
  end

  def order(variant, quantity:)
    order = create(:order, distributor: shop, order_cycle:)
    create(:line_item, order:, variant:, quantity:)
    order.update_columns(state: "complete", completed_at: Time.zone.now)
  end

  it "gives a producer with a capacity its own pallet, named after the producer" do
    exchange_of(esposito).update!(pallet_capacity: 240, pallet_minimum_fill: 60)

    pallet = pallets.list.sole
    expect(pallet.name).to eq "Caseificio Esposito"
    expect(pallet.capacity).to eq 240
    expect(pallet.minimum_fill).to eq 0.6
    expect(pallet.producer_ids).to eq [esposito.id]
  end

  it "lets producers with the same pallet name share one pallet" do
    exchange_of(ferrer).update!(pallet_name: "Valencia", pallet_capacity: 800,
                                pallet_minimum_fill: 80)
    exchange_of(molina).update!(pallet_name: "valencia ", pallet_capacity: 600)
    exchange_of(esposito).update!(pallet_capacity: 240)

    expect(pallets.list.map(&:name)).to eq ["Valencia", "Caseificio Esposito"]
    valencia = pallets.list.first
    expect(valencia.producer_ids).to contain_exactly(ferrer.id, molina.id)
    expect(valencia.capacity).to eq 800
    expect(valencia.minimum_fill).to eq 0.8
  end

  it "fills each pallet only with its producers' products" do
    exchange_of(ferrer).update!(pallet_name: "Valencia", pallet_capacity: 800)
    exchange_of(esposito).update!(pallet_capacity: 240)
    order(variant_of(ferrer, weight: 10), quantity: 3)
    order(variant_of(esposito, weight: 1), quantity: 4)

    expect(pallets.for_producer(ferrer.id).ordered_weight).to eq 30
    expect(pallets.for_producer(esposito.id).ordered_weight).to eq 4
  end

  it "has no pallet for a producer without one" do
    exchange_of(esposito).update!(pallet_capacity: 240)

    expect(pallets.for_producer(ferrer.id)).to be_nil
  end

  it "falls back to the order cycle's pallet for everyone" do
    order_cycle.update!(preferred_pallet_capacity: 800)

    pallet = pallets.list.sole
    expect(pallet.name).to be_nil
    expect(pallets.for_producer(ferrer.id)).to eq pallet
    expect(pallets.for_producer(esposito.id)).to eq pallet
  end

  it "has no pallets when none are set" do
    expect(pallets.list).to be_empty
  end
end
