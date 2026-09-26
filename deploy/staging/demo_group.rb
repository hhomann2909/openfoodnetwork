# frozen_string_literal: true

# Fork only: the demo group "Erzeuger aus Südeuropa" with the five demo producers, so the
# Groups page has something to show. Safe to run again.
#   bin/rails runner deploy/staging/demo_group.rb
FORK_FILES = Rails.root.join("spec/fixtures/files/fork")
PRODUCERS = [
  "Finca Els Tarongers (Beispiel)", "Huerta La Molina (Beispiel)",
  "Olivar Sierra Mágina (Beispiel)", "Caseificio Santa Lucia (Beispiel)",
  "Agrumi Russo (Beispiel)",
].freeze

admin = Spree::User.find_by!(admin: true)
germany = Spree::Country.find_by!(iso: "DE")

group = EnterpriseGroup.find_or_initialize_by(name: "Erzeuger aus Südeuropa (Beispiel)")
group.assign_attributes(
  owner: admin,
  on_front_page: true,
  description: "Kleine Höfe aus Spanien und Italien, die über gemeinsame Paletten liefern",
  long_description: <<~HTML,
    <p>Orangen und Clementinen aus Valencia, Avocados aus der Axarquía, Olivenöl und Mandeln
    aus Jaén, Büffelmozzarella aus Kampanien und Zitronen aus Sizilien: Diese Höfe verkaufen
    direkt an dich. Ihre Bestellungen reisen gemeinsam auf einer Palette pro Region zu
    Hofläden und Food-Coops im Münsterland.</p>
    <p lang="es"><em>Pequeñas fincas de España e Italia que venden directamente y envían
    juntas en un palé por región a tiendas de granja y cooperativas del norte.</em></p>
    <p><small>Beispielgruppe · Grupo de ejemplo</small></p>
  HTML
  address: group.address || Spree::Address.new(
    address1: "Borghorster Str. 68", city: "Laer", zipcode: "48366", country: germany,
    state: germany.states.find_by(abbr: "NW")
  )
)
group.enterprises = Enterprise.where(name: PRODUCERS)
group.save!

unless group.logo.attached?
  group.logo.attach(io: File.open(FORK_FILES.join("logo-gruppe-sued.png")),
                    filename: "logo-gruppe-sued.png", content_type: "image/png")
end
unless group.promo_image.attached?
  group.promo_image.attach(io: File.open(FORK_FILES.join("photos/promo-ferrer.jpg")),
                           filename: "promo-gruppe.jpg", content_type: "image/jpeg")
end

puts "Group #{group.name} (/groups/#{group.permalink}): #{group.enterprises.count} producers"
