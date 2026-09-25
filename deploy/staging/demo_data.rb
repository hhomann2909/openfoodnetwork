# frozen_string_literal: true

# Fork only: demo data for the OFN staging instance (ofn.hof-homann.de), so the south-north
# marketplace features can be seen right away. Everything is marked as an example ("Beispiel").
# Run once after seeding:  bin/rails runner deploy/staging/demo_data.rb
#
# Scenario: producers in Spain and Italy sell through one order cycle coordinated by
# "Fair Europe Food eG (Beispiel)", delivered on a shared pallet to two hubs in Münsterland.

COORDINATOR_NAME = "Fair Europe Food eG (Beispiel)"

if Enterprise.exists?(name: COORDINATOR_NAME)
  puts "Demo data already there, nothing to do."
  return
end

IMAGES = Rails.root.join("spec/fixtures/files/fork")
admin = Spree::User.find_by!(admin: true)
admin.update!(enterprise_limit: 100)

germany = Spree::Country.find_by!(iso: "DE")
nrw = germany.states.find_by!(abbr: "NW")
spain = Spree::Country.find_by!(iso: "ES")
italy = Spree::Country.find_by!(iso: "IT")

# Addresses need a state whenever the country requires one, and OFN reads the free text
# state_name through the state, so producers in the south need their regions as states.
REGIONS = {
  "ES" => [["Andalucía", "AN"], ["Aragón", "AR"], ["Asturias", "AS"], ["Illes Balears", "IB"],
           ["Canarias", "CN"], ["Cantabria", "CB"], ["Castilla-La Mancha", "CM"],
           ["Castilla y León", "CL"], ["Cataluña", "CT"], ["Extremadura", "EX"],
           ["Galicia", "GA"], ["La Rioja", "RI"], ["Madrid", "MD"], ["Murcia", "MC"],
           ["Navarra", "NC"], ["País Vasco", "PV"], ["Comunitat Valenciana", "VC"],
           ["Ceuta", "CE"], ["Melilla", "ML"]],
  "IT" => [["Abruzzo", "65"], ["Basilicata", "77"], ["Calabria", "78"], ["Campania", "72"],
           ["Emilia-Romagna", "45"], ["Friuli-Venezia Giulia", "36"], ["Lazio", "62"],
           ["Liguria", "42"], ["Lombardia", "25"], ["Marche", "57"], ["Molise", "67"],
           ["Piemonte", "21"], ["Puglia", "75"], ["Sardegna", "88"], ["Sicilia", "82"],
           ["Toscana", "52"], ["Trentino-Alto Adige", "32"], ["Umbria", "55"],
           ["Valle d'Aosta", "23"], ["Veneto", "34"]],
}.freeze

REGIONS.each do |iso, regions|
  country = Spree::Country.find_by!(iso:)
  regions.each do |name, abbr|
    Spree::State.find_or_create_by!(country:, name:) { |state| state.abbr = abbr }
  end
end

def address(country, city, street, zipcode, state: nil, region: nil)
  state ||= country.states.find_by!(name: region) if region
  Spree::Address.new(firstname: "Beispiel", lastname: "Betrieb", address1: street, city:,
                     zipcode:, phone: "+49 2554 0000", country:, state:)
end

def enterprise(owner, **attributes)
  Enterprise.create!(owner:, visible: "public", **attributes)
end

ActiveRecord::Base.transaction do
  # Hubs and coordinator (sell any, need shipping and payment to be ready for checkout)
  coordinator = enterprise(
    admin, name: COORDINATOR_NAME, sells: "any", is_primary_producer: false,
           description: "Organisiert die Palette aus dem Süden (Beispiel)",
           address: address(germany, "Laer", "Borghorster Str. 68", "48366", state: nrw)
  )
  hubs = [
    ["Hof Homann eG (Beispiel-Hub)", "Borghorster Str. 68", "Laer", "48366",
     "Hofladen der Genossenschaft, Abholung Sa 10-13 Uhr"],
    ["Food-Coop Wurzelwerk (Beispiel)", "Kreuzstraße 1", "Münster", "48143",
     "Food-Coop im Kreuzviertel, Abholung Fr 16-19 Uhr"],
  ].map do |name, street, city, zipcode, description|
    enterprise(admin, name:, sells: "any", is_primary_producer: false, description:,
                      address: address(germany, city, street, zipcode, state: nrw))
  end

  (hubs + [coordinator]).each do |shop|
    shipping = Spree::ShippingMethod.new(
      name: "Abholung (Beispiel)", display_on: "", require_ship_address: false,
      calculator: Calculator::FlatRate.new(preferred_amount: 0), distributors: [shop]
    )
    shipping.shipping_categories << DefaultShippingCategory.find_or_create
    shipping.save!
    Spree::PaymentMethod::Check.create!(name: "Bar bei Abholung (Beispiel)",
                                        environment: Rails.env, distributors: [shop])
  end

  # Producers in the south
  producers = {
    ferrer: ["Finca Els Tarongers (Beispiel)", spain, "Alzira", "46600", "Comunitat Valenciana",
             "Drei Generationen, 11 ha Orangen und Clementinen am Río Júcar. Seit 2019 bio."],
    molina: ["Huerta La Molina (Beispiel)", spain, "Vélez-Málaga", "29700", "Andalucía",
             "Avocados von Terrassenhängen der Axarquía, 38 % aufbereitetes Wasser."],
    jimenez: ["Olivar Sierra Mágina (Beispiel)", spain, "Bélmez de la Moraleda", "23568",
              "Andalucía",
              "Olivenhain auf 800 m, Frühernte Picual, Mandeln vom Nachbarhang."],
    esposito: ["Caseificio Santa Lucia (Beispiel)", italy, "Battipaglia", "84091", "Campania",
               "Kleine Käserei mit 140 Büffeln in der Piana del Sele."],
    russo: ["Agrumi Russo (Beispiel)", italy, "Siracusa", "96100", "Sicilia",
            "Zitronen und Tarocco-Blutorangen am Fuß der Iblei-Berge."],
  }.transform_values do |name, country, city, zipcode, region, description|
    enterprise(admin, name:, sells: "none", is_primary_producer: true,
                      description: city, long_description: description,
                      address: address(country, city, "Camino Rural 1", zipcode, region:))
  end

  # Enterprises of one owner are related automatically; grant what the order cycle needs.
  allow = lambda do |parent, child|
    relationship = EnterpriseRelationship.find_or_initialize_by(parent:, child:)
    relationship.permissions_list = ["add_to_order_cycle"]
    relationship.save!
  end
  producers.each_value { |producer| allow.call(producer, coordinator) }
  hubs.each { |hub| allow.call(coordinator, hub) }

  # Products
  taxonomy = Spree::Taxonomy.find_or_create_by!(name: "Produkte")
  taxon = ->(name) { Spree::Taxon.find_or_create_by!(name:, taxonomy:, parent: taxonomy.root) }

  products = [
    ["Bio-Orangen Navelina", :ferrer, "orangen", 23.70, 10, "Obst",
     "Klasse I, Kaliber 3-4. Geerntet nach Bestellschluss."],
    ["Bio-Clementinen Clemenules", :ferrer, "clementinen", 14.40, 5, "Obst",
     "Klasse I, kernlos, unbehandelt."],
    ["Avocado Hass", :molina, "avocado", 16.20, 3, "Obst",
     "Hart geerntet, bei Zimmertemperatur in 3-5 Tagen essreif."],
    ["Mozzarella di Bufala Campana DOP", :esposito, "mozzarella", 13.20, 1, "Käse",
     "4 x 250 g. Am Abfahrtstag hergestellt, reist gekühlt bei 2-7 °C."],
    ["Olivenöl nativ extra, Picual", :jimenez, "olivenoel", 29.00, 3, "Öl & Nüsse",
     "Frühernte Oktober, kaltgepresst."],
    ["Bio-Mandeln Marcona", :jimenez, "mandeln", 12.50, 1, "Öl & Nüsse", "Geschält."],
    ["Bio-Zitronen Femminello", :russo, "zitronen", 13.70, 5, "Obst",
     "Unbehandelt, Schale zum Verzehr geeignet."],
    ["Bio-Blutorangen Tarocco", :russo, "blutorangen", 22.10, 8, "Obst",
     "Vorbestellung, erste Ernte ab Ende November."],
  ].map do |name, producer, image, price, kg, category, description|
    product = Spree::Product.create!(
      name:, description:, price:, enterprise_id: producers.fetch(producer).id,
      primary_taxon_id: taxon.call(category).id, variant_unit: "weight",
      variant_unit_scale: 1000, unit_value: kg * 1000, sku: "BSP-#{image.upcase}"
    )
    product.variants.first.update!(on_hand: 500)
    Spree::Image.create!(
      viewable: product,
      attachment: { io: File.open(IMAGES.join("#{image}.jpg")), filename: "#{image}.jpg",
                    content_type: "image/jpeg" }
    )
    product
  end
  variants = products.map { |product| product.variants.first }

  # Order cycle: one shared pallet, fees for freight, platform and pick-up point
  freight = EnterpriseFee.create!(
    enterprise: coordinator, fee_type: "transport", name: "Palettenfracht",
    calculator: Calculator::Weight.new(preferred_per_unit: 0.36, preferred_unit_from_list: "kg")
  )
  platform = EnterpriseFee.create!(
    enterprise: coordinator, fee_type: "admin", name: "Genossenschaftliche Plattform",
    calculator: Calculator::FlatPercentPerItem.new(preferred_flat_percent: 8)
  )

  order_cycle = OrderCycle.create!(
    name: "Valencia, Andalusien und Kampanien → Münsterland (Beispiel)",
    coordinator:, orders_open_at: 1.day.ago, orders_close_at: 5.days.from_now.change(hour: 22),
    coordinator_fees: [freight, platform]
  )
  producers.each_value do |producer|
    Exchange.create!(order_cycle:, sender: producer, receiver: coordinator, incoming: true,
                     variants: variants.select { |variant| variant.enterprise_id == producer.id })
  end
  hubs.each do |hub|
    exchange = Exchange.create!(order_cycle:, sender: coordinator, receiver: hub, incoming: false,
                                variants:, pickup_time: hub.description.split(", ").last)
    exchange.enterprise_fees << EnterpriseFee.create!(
      enterprise: hub, fee_type: "sales", name: "Abholpunkt",
      calculator: Calculator::FlatPercentPerItem.new(preferred_flat_percent: 9)
    )
  end
  order_cycle.update!(preferred_pallet_capacity: 800, preferred_pallet_minimum_fill: 80)

  # Some orders so the pallet shows progress (about 60 %)
  12.times do |i|
    order = Spree::Order.create!(distributor: hubs.first, order_cycle:,
                                 email: "beispiel-#{i}@example.org")
    order.line_items.create!(variant: variants.first, quantity: 4, price: 23.70)
    order.update_columns(state: "complete", completed_at: Time.zone.now)
  end
end

%w[home_products product_grid_view pallet_progress].each { |feature| Flipper.enable(feature) }

puts "Demo data created: #{Enterprise.count} enterprises, #{Spree::Product.count} products."
