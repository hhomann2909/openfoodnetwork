# frozen_string_literal: true

RSpec.describe PalletProgressComponent, type: :component do
  def progress(**overrides)
    instance_double(
      OrderCycles::PalletProgress,
      name: nil, tracked?: true, capacity: 800.to_d, ordered_weight: 576.to_d, fill: 0.72.to_d,
      minimum_fill: 0.8.to_d, minimum?: true, confirmed?: false, weight_to_confirm: 64.to_d,
      **overrides
    )
  end

  it "shows how full the pallet is and what is missing for delivery" do
    render_inline(described_class.new(progress: progress))

    expect(page).to have_selector ".pallet-progress-fill", text: "72%"
    expect(page).to have_selector ".pallet-progress-status", text: "64 kg more for delivery"
    expect(page).to have_selector ".pallet-progress-detail", text: "576 kg of 800 kg ordered"
    expect(page).to have_selector ".pallet-progress-explanation", text: "once it is 80% full"
  end

  it "draws the fill and the minimum to scale" do
    render_inline(described_class.new(progress: progress))

    expect(page.find(".pallet-progress-bar-fill")[:style]).to eq "width: 72%"
    expect(page.find(".pallet-progress-minimum")[:style]).to eq "left: 80%"
    expect(page.find(".pallet-progress-bar")["aria-valuenow"]).to eq "72"
  end

  it "names a pallet of a producer or region" do
    render_inline(described_class.new(progress: progress(name: "Valencia")))

    expect(page).to have_selector ".pallet-progress-title", text: "Shared pallet Valencia"
  end

  it "says when the delivery is confirmed" do
    render_inline(described_class.new(progress: progress(confirmed?: true, fill: 0.85.to_d)))

    expect(page).to have_selector ".pallet-progress.confirmed"
    expect(page).to have_selector ".pallet-progress-status", text: "Delivery confirmed"
  end

  it "shows no minimum when there is none" do
    render_inline(described_class.new(progress: progress(minimum?: false, minimum_fill: 0.to_d)))

    expect(page).not_to have_selector ".pallet-progress-minimum"
    expect(page).not_to have_selector ".pallet-progress-status"
  end

  it "leaves out the details when compact" do
    render_inline(described_class.new(progress: progress, compact: true))

    expect(page).to have_selector ".pallet-progress.compact .pallet-progress-bar"
    expect(page).to have_selector ".pallet-progress-status", text: "64 kg to go"
    expect(page).not_to have_selector ".pallet-progress-detail"
  end

  it "renders nothing for an order cycle without a pallet" do
    render_inline(described_class.new(progress: progress(tracked?: false)))

    expect(page).not_to have_selector ".pallet-progress"
  end
end
