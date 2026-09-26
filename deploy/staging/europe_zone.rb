# frozen_string_literal: true

# Fork only: the checkout zone for a European instance. OFN's seeded "EU_VAT" zone predates
# Brexit and misses Greece, Czechia and Croatia, so producers there couldn't register their
# address. Set CHECKOUT_ZONE="Europe" in /opt/ofn/ofn.env afterwards. Safe to run again.
#   bin/rails runner deploy/staging/europe_zone.rb
EU_MEMBERS = %w[AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES
                SE].freeze

zone = Spree::Zone.find_or_initialize_by(name: "Europe")
zone.description = "EU member states (single market)"
countries = Spree::Country.where(iso: EU_MEMBERS).to_a
missing = EU_MEMBERS - countries.map(&:iso)
raise "Countries missing: #{missing.join(', ')}" if missing.any?

zone.zone_members.destroy_all if zone.persisted?
countries.each { |country| zone.zone_members.build(zoneable: country) }
zone.save!

puts "Zone Europe: #{zone.reload.countries.count} countries"
