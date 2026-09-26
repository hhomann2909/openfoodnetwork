# frozen_string_literal: true

# Fork only: instance settings for the staging instance, replacing OFN's defaults that point to
# other instances (Australia, UK) or to hello@openfoodnetwork.org. Safe to run again.
#   bin/rails runner deploy/staging/content_config.rb
LEGAL = "https://hof-homann.de/openfoodnetwork"

Spree::Preference.count # open the connection, otherwise preferences are only cached

ContentConfig.footer_facebook_url = ""
ContentConfig.footer_twitter_url = ""
ContentConfig.footer_instagram_url = ""
ContentConfig.footer_linkedin_url = ""
# No official contact address for this instance yet: hide the mail link until there is one.
ContentConfig.footer_email = ENV.fetch("OFN_CONTACT_EMAIL", "")
ContentConfig.footer_about_url = "#{LEGAL}/ueber-uns"
ContentConfig.footer_links_md = <<~MD
  [Impressum](#{LEGAL}/impressum)

  [Datenschutz](#{LEGAL}/datenschutz)

  [Über uns](#{LEGAL}/ueber-uns)
MD

# OpenStreetMap everywhere instead of Google Maps (no API key, no data to Google).
ContentConfig.open_street_map_enabled = true
ContentConfig.open_street_map_provider_name = "OpenStreetMap.Mapnik"
ContentConfig.open_street_map_default_latitude = "46.5"
ContentConfig.open_street_map_default_longitude = "8.5"

Spree::Config.privacy_policy_url = "#{LEGAL}/datenschutz"

puts "Content settings applied."
