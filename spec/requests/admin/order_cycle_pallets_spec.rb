# frozen_string_literal: true

RSpec.describe "Admin order cycle pallets" do
  include AuthenticationHelper

  let(:coordinator) { create(:distributor_enterprise) }
  let(:producer) { create(:supplier_enterprise) }
  let(:order_cycle) {
    create(:simple_order_cycle, coordinator:, suppliers: [producer], distributors: [coordinator])
  }
  let(:exchange) { order_cycle.exchanges.incoming.first }

  def update_pallets
    patch update_pallets_admin_order_cycle_path(order_cycle), params: {
      pallets: { exchange.id => { pallet_name: " Valencia ", pallet_capacity: "800",
                                  pallet_minimum_fill: "120" } }
    }
  end

  it "saves the pallets of the incoming exchanges for the coordinator" do
    login_as coordinator.owner

    update_pallets

    expect(response).to redirect_to edit_admin_order_cycle_path(order_cycle)
    expect(exchange.reload).to have_attributes(pallet_name: "Valencia", pallet_capacity: 800,
                                               pallet_minimum_fill: 100)
  end

  it "doesn't let others change them" do
    login_as create(:user)

    update_pallets

    expect(exchange.reload.pallet_capacity).to eq 0
  end
end
