# frozen_string_literal: true

# Fork only: puts the demo enterprises created before the origin map on it.
# bin/rails runner deploy/staging/locate_demo.rb
coordinates = {
  "Hof Homann eG (Beispiel-Hub)" => [52.0550, 7.3570],
  "Food-Coop Wurzelwerk (Beispiel)" => [51.9695, 7.6195],
  "Finca Els Tarongers (Beispiel)" => [39.1506, -0.4353],
  "Huerta La Molina (Beispiel)" => [36.7806, -4.1004],
  "Olivar Sierra Mágina (Beispiel)" => [37.7236, -3.3806],
  "Caseificio Santa Lucia (Beispiel)" => [40.6083, 14.9869],
  "Agrumi Russo (Beispiel)" => [37.0755, 15.2866],
}
coordinates.each do |name, (latitude, longitude)|
  Enterprise.find_by!(name:).address.update_columns(latitude:, longitude:)
end
puts "Located #{coordinates.size} demo enterprises."
