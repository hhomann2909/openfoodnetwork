# frozen_string_literal: true

module CountryNameHelper
  # Country names are stored in English. Instances can translate them under
  # spree.country_names, the same way the checkout's country list does.
  def country_display_name(country)
    Spree.t(country.iso, scope: "country_names", default: country.name)
  end
end
