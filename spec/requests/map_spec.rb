# frozen_string_literal: true

RSpec.describe MapController do
  describe "GET /map" do
    let(:producer) { create(:supplier_enterprise, name: "Finca Ferrer") }

    before { producer.address.update_columns(latitude: 39.15, longitude: -0.43) }

    it "shows the origin map without Google Maps", feature: :origin_map do
      get map_path

      expect(response).to have_http_status :ok
      expect(response.body).to include 'data-controller="origin-map"'
      expect(response.body).to include "Finca Ferrer"
      expect(response.body).not_to include "maps.googleapis.com"
    end

    it "keeps the stock map while the feature is off" do
      get map_path

      expect(response).to have_http_status :ok
      expect(response.body).not_to include 'data-controller="origin-map"'
    end
  end
end
