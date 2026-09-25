# frozen_string_literal: true

require 'system_helper'

# Fork only: renders our features next to the stock OFN pages with realistic data and saves
# full page screenshots to tmp/screenshots, for design reviews. Run by the "Screenshots" workflow.
RSpec.describe "Design screenshots", type: :system do
  include AuthenticationHelper

  DIR = Rails.root.join("tmp/screenshots")
  SIZES = { desktop: [1280, 900], mobile: [390, 844] }.freeze

  def shot(name, size)
    page.driver.resize(*SIZES.fetch(size))
    # Scroll through the page once so lazy loaded images are in before the full page capture.
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    sleep 1
    page.execute_script("window.scrollTo(0, 0)")
    sleep 0.5
    FileUtils.mkdir_p(DIR)
    page.save_screenshot(DIR.join("#{name}-#{size}.png").to_s, full: true)
  end

  def country(iso, name, numcode)
    Spree::Country.find_by(iso:) ||
      create(:country, iso:, iso3: "#{iso}X", iso_name: name.upcase, name:, numcode:)
  end

  def producer(name, place, country, description)
    create(:supplier_enterprise, name:, description: place, long_description: description).tap do |p|
      p.address.update_columns(country_id: country.id, state_id: nil, city: place)
    end
  end

  def product(name, producer, image, price:, kg:, description:)
    create(:product, name:, enterprise_id: producer.id, price:, on_hand: 200,
                     variant_unit: "weight", variant_unit_scale: 1000, unit_value: kg * 1000,
                     description:).tap do |product|
      Spree::Image.create!(
        attachment: Rack::Test::UploadedFile.new(
          Rails.root.join("spec/fixtures/files/fork/#{image}.jpg"), "image/jpeg"
        ),
        viewable: product
      )
    end
  end

  let(:spain) { country("ES", "Spain", 724) }
  let(:italy) { country("IT", "Italy", 380) }

  let!(:coordinator) {
    create(:distributor_enterprise, name: "Fair Europe Food eG", with_payment_and_shipping: true)
  }
  let!(:hub) {
    create(:distributor_enterprise, :with_logo_image, :with_promo_image,
           name: "Hof Homann eG", with_payment_and_shipping: true,
           description: "Genossenschaft und Hofladen in Laer")
  }
  let!(:food_coop) {
    create(:distributor_enterprise, name: "Food-Coop Wurzelwerk", with_payment_and_shipping: true)
  }

  let(:ferrer) {
    producer("Finca Els Tarongers", "Alzira, Valencia", spain,
             "Three generations growing oranges and clementines on the Júcar river.")
  }
  let(:molina) { producer("Huerta La Molina", "Vélez-Málaga", spain, "Avocados from terraces.") }
  let(:jimenez) { producer("Olivar Sierra Mágina", "Jaén", spain, "Olive grove at 800 m.") }
  let(:esposito) {
    producer("Caseificio Santa Lucia", "Battipaglia, Campania", italy, "Buffalo dairy.")
  }
  let(:russo) { producer("Agrumi Russo", "Siracusa, Sicily", italy, "Lemons and blood oranges.") }

  let!(:products) {
    [
      product("Organic Navel Oranges", ferrer, "orangen", price: 23.70, kg: 10,
                                                         description: "Harvested after ordering."),
      product("Organic Clementines", ferrer, "clementinen", price: 14.40, kg: 5,
                                                             description: "Clemenules, seedless."),
      product("Hass Avocados", molina, "avocado", price: 16.20, kg: 3,
                                                  description: "Picked firm, ripe in 3-5 days."),
      product("Mozzarella di Bufala Campana DOP", esposito, "mozzarella",
              price: 13.20, kg: 1, description: "Made on the day the truck leaves."),
      product("Extra Virgin Olive Oil, Picual", jimenez, "olivenoel",
              price: 29.00, kg: 3, description: "Early harvest, cold pressed."),
      product("Organic Marcona Almonds", jimenez, "mandeln", price: 12.50, kg: 1,
                                                             description: "Shelled."),
      product("Organic Femminello Lemons", russo, "zitronen", price: 13.70, kg: 5,
                                                               description: "Unwaxed."),
      product("Organic Tarocco Blood Oranges", russo, "blutorangen",
              price: 22.10, kg: 8, description: "First harvest from late November."),
    ]
  }

  let!(:order_cycle) {
    create(:simple_order_cycle,
           name: "Valencia, Andalusia and Campania to Münsterland",
           coordinator:, distributors: [hub, food_coop],
           suppliers: [ferrer, molina, jimenez, esposito, russo],
           variants: products.map { |product| product.variants.first },
           orders_open_at: 2.days.ago, orders_close_at: 3.days.from_now + 4.hours,
           coordinator_fees: [
             create(:enterprise_fee, enterprise: coordinator, fee_type: "transport",
                                     name: "Pallet freight",
                                     calculator: Calculator::Weight.new(preferred_per_unit: 0.36)),
             create(:enterprise_fee, enterprise: coordinator, fee_type: "admin",
                                     name: "Cooperative platform",
                                     calculator: Calculator::FlatPercentPerItem.new(
                                       preferred_flat_percent: 8
                                     )),
           ])
  }

  before do
    Flipper.enable(:home_products)
    Flipper.enable(:product_grid_view)
    Flipper.enable(:pallet_progress)

    order_cycle.exchanges.outgoing.each do |exchange|
      exchange.enterprise_fees << create(
        :enterprise_fee, enterprise: exchange.receiver, fee_type: "sales", name: "Pick-up point",
                         calculator: Calculator::FlatPercentPerItem.new(preferred_flat_percent: 9)
      )
    end
    order_cycle.update!(preferred_pallet_capacity: 800, preferred_pallet_minimum_fill: 80)

    oranges = products.first.variants.first
    12.times do
      order = create(:order, distributor: hub, order_cycle:)
      create(:line_item, order:, variant: oranges, quantity: 4)
      order.update_columns(state: "complete", completed_at: Time.zone.now)
    end
  end

  it "renders the pages" do
    visit root_path
    expect(page).to have_selector ".home-product"
    shot("01-home", :desktop)
    shot("01-home", :mobile)

    visit root_path(origin: "IT")
    shot("02-home-origin-italy", :desktop)

    visit shops_path
    expect(page).to have_content "Hof Homann eG"
    shot("03-stock-ofn-shops", :desktop)
    shot("03-stock-ofn-shops", :mobile)

    visit enterprise_shop_path(hub)
    expect(page).to have_selector ".product-item"
    shot("04-shop-grid", :desktop)
    shot("04-shop-grid", :mobile)

    page.driver.resize(*SIZES[:desktop])
    first(".product-link").click
    expect(page).to have_selector ".price-breakdown"
    shot("05-product-modal", :desktop)
    page.driver.resize(*SIZES[:mobile])
    shot("05-product-modal", :mobile)

    login_as_admin
    visit edit_admin_order_cycle_path(order_cycle)
    click_button "Advanced Settings"
    expect(page).to have_field "order_cycle_preferred_pallet_capacity"
    shot("06-admin-advanced-settings", :desktop)
  end
end
