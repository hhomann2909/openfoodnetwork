# frozen_string_literal: true

# Fork only: gives the demo products and enterprises real photos (free Unsplash photos, see
# spec/fixtures/files/fork/photos/CREDITS.md) instead of the drawn placeholders. Safe to run again.
#   bin/rails runner deploy/staging/use_demo_photos.rb
PHOTOS = Rails.root.join("spec/fixtures/files/fork/photos")

def upload(file)
  { io: File.open(PHOTOS.join(file)), filename: file, content_type: "image/jpeg" }
end

{
  "Bio-Orangen Navelina" => "product-orangen.jpg",
  "Bio-Clementinen Clemenules" => "product-clementinen.jpg",
  "Avocado Hass" => "product-avocado.jpg",
  "Mozzarella di Bufala Campana DOP" => "product-mozzarella.jpg",
  "Olivenöl nativ extra, Picual" => "product-olivenoel.jpg",
  "Bio-Mandeln Marcona" => "product-mandeln.jpg",
  "Bio-Zitronen Femminello" => "product-zitronen.jpg",
  "Bio-Blutorangen Tarocco" => "product-blutorangen.jpg",
}.each do |name, file|
  product = Spree::Product.find_by(name:)
  next puts("Missing product #{name}") unless product

  product.images.destroy_all
  Spree::Image.create!(viewable: product, attachment: upload(file), alt: name)
end

{
  "Finca Els Tarongers (Beispiel)" => "promo-ferrer.jpg",
  "Huerta La Molina (Beispiel)" => "promo-molina.jpg",
  "Olivar Sierra Mágina (Beispiel)" => "promo-jimenez.jpg",
  "Caseificio Santa Lucia (Beispiel)" => "promo-esposito.jpg",
  "Agrumi Russo (Beispiel)" => "promo-russo.jpg",
  "Hof Homann eG (Beispiel-Hub)" => "promo-homann.jpg",
  "Food-Coop Wurzelwerk (Beispiel)" => "promo-wurzelwerk.jpg",
}.each do |name, file|
  enterprise = Enterprise.find_by(name:)
  next puts("Missing enterprise #{name}") unless enterprise

  enterprise.promo_image.attach(upload(file))
end

puts "Demo photos in place."
