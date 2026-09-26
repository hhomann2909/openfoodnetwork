# frozen_string_literal: true

# Fork only: brings the demo enterprises to life for demos (logos, a promo image, stories in
# German and Spanish) and fills the shared pallet to just below its minimum, so one order of four
# boxes of oranges confirms the delivery live. Safe to run again.
#   bin/rails runner deploy/staging/enhance_demo.rb

IMAGES = Rails.root.join("spec/fixtures/files/fork") unless defined?(IMAGES)

def attach(record, attachment, file)
  return if record.public_send(attachment).attached?

  record.public_send(attachment).attach(
    io: File.open(IMAGES.join(file)), filename: file,
    content_type: file.end_with?(".png") ? "image/png" : "image/jpeg"
  )
end

stories = {
  "Finca Els Tarongers (Beispiel)" => [
    "logo-ferrer.png",
    "Drei Generationen, 11 Hektar Orangen und Clementinen am Río Júcar bei Alzira, seit 2019 " \
    "bio-zertifiziert. Zwischen den Baumreihen blühen Wildkräuter für Nützlinge, bewässert wird " \
    "tropfenweise aus der historischen Acequia Real del Júcar. Geerntet wird erst, wenn eure " \
    "Bestellung da ist: Bis dahin hängen die Orangen am Baum.",
    "Tres generaciones, 11 hectáreas de naranjas y clementinas junto al río Júcar, en Alzira, " \
    "con certificación ecológica desde 2019. Entre las filas florecen hierbas silvestres para la " \
    "fauna auxiliar y regamos por goteo desde la histórica Acequia Real del Júcar. Cosechamos " \
    "cuando llega tu pedido: hasta entonces, las naranjas siguen en el árbol.",
  ],
  "Huerta La Molina (Beispiel)" => [
    "logo-molina.png",
    "Vier Hektar Avocados an den Terrassenhängen der Axarquía. Seit die Stauseen 2023 unter " \
    "10 % fielen, bewässern wir zu 38 % mit aufbereitetem Wasser.",
    "Cuatro hectáreas de aguacates en las laderas en terrazas de la Axarquía. Desde que los " \
    "embalses bajaron del 10 % en 2023, regamos un 38 % con agua regenerada.",
  ],
  "Olivar Sierra Mágina (Beispiel)" => [
    "logo-jimenez.png",
    "Olivenhain auf 800 Metern, Sorte Picual, Frühernte im Oktober und Pressung innerhalb von " \
    "vier Stunden in der Mühle der Dorfgenossenschaft.",
    "Olivar a 800 metros, variedad picual, cosecha temprana en octubre y molienda en menos de " \
    "cuatro horas en la almazara de la cooperativa del pueblo.",
  ],
  "Caseificio Santa Lucia (Beispiel)" => [
    "logo-esposito.png",
    "140 Büffel auf eigenen Weiden in der Piana del Sele. Die Mozzarella wird am Tag der " \
    "Abfahrt gezogen und reist gekühlt bei 2 bis 7 °C.",
    "140 búfalas en pastos propios de la Piana del Sele. La mozzarella se hila el día de salida " \
    "y viaja refrigerada entre 2 y 7 °C.",
  ],
  "Agrumi Russo (Beispiel)" => [
    "logo-russo.png",
    "Zitronen der Sorte Femminello und Tarocco-Blutorangen am Fuß der Iblei-Berge, mit " \
    "unbehandelter Schale.",
    "Limones femminello y naranjas sanguinas tarocco al pie de los montes Iblei, con piel sin " \
    "tratar.",
  ],
  "Hof Homann eG (Beispiel-Hub)" => ["logo-homann.png", nil, nil],
  "Food-Coop Wurzelwerk (Beispiel)" => ["logo-wurzelwerk.png", nil, nil],
}

stories.each do |name, (logo, german, spanish)|
  enterprise = Enterprise.find_by(name:)
  next unless enterprise

  attach(enterprise, :logo, logo)
  next unless german

  enterprise.update!(long_description: <<~HTML)
    <p>#{german}</p>
    <p lang="es"><em>#{spanish}</em></p>
    <p><small>Beispielbetrieb · Explotación de ejemplo</small></p>
  HTML
end

if (ferrer = Enterprise.find_by(name: "Finca Els Tarongers (Beispiel)"))
  attach(ferrer, :promo_image, "promo-ferrer.jpg")
  ferrer.set_producer_property("Bio", "ES-ECO-020-CV (Beispiel)")
end

# One pallet per region: [pallet name, producers, capacity kg, minimum %, product to fill with,
# target kg]. Valencia stays just below its minimum for the live demo; the others show the range
# from just started to already confirmed.
REGION_PALLETS = [
  ["Valencia", ["Finca Els Tarongers (Beispiel)"], 800, 80, "Bio-Orangen Navelina", 600],
  ["Andalusien", ["Huerta La Molina (Beispiel)", "Olivar Sierra Mágina (Beispiel)"], 600, 70,
   "Avocado Hass", 324],
  ["Kampanien (Kühlware)", ["Caseificio Santa Lucia (Beispiel)"], 240, 60,
   "Mozzarella di Bufala Campana DOP", 211],
  ["Sizilien", ["Agrumi Russo (Beispiel)"], 500, 70, "Bio-Zitronen Femminello", 155],
].freeze

order_cycle = OrderCycle.find_by("name LIKE ?", "%Münsterland (Beispiel)%")
if order_cycle
  hub = Enterprise.find_by(name: "Hof Homann eG (Beispiel-Hub)")
  pallets = OrderCycles::Pallets

  REGION_PALLETS.each do |pallet_name, producer_names, capacity, minimum, product_name, target|
    producers = Enterprise.where(name: producer_names)
    order_cycle.exchanges.incoming.where(sender: producers).
      update_all(pallet_name:, pallet_capacity: capacity, pallet_minimum_fill: minimum)

    pallet = pallets.new(order_cycle.reload).for_producer(producers.first.id)
    variant = Spree::Variant.joins(:product).find_by!(spree_products: { name: product_name })
    missing_units = ((target - pallet.ordered_weight) / variant.weight).floor
    index = 0
    while missing_units.positive?
      quantity = [missing_units, 20].min
      order = Spree::Order.create!(
        distributor: hub, order_cycle:,
        email: "beispiel-#{pallet_name.parameterize}-#{index}@example.org"
      )
      order.line_items.create!(variant:, quantity:, price: variant.price)
      order.update_columns(state: "complete", completed_at: Time.zone.now)
      missing_units -= quantity
      index += 1
    end
  end

  pallets.new(order_cycle.reload).all.each do |pallet|
    puts "Pallet #{pallet.name}: #{pallet.ordered_weight.to_i} of #{pallet.capacity.to_i} kg "          "(#{(pallet.fill * 100).round} %, minimum #{(pallet.minimum_fill * 100).round} %)"
  end
end

puts "Demo enterprises enhanced."
