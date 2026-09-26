# frozen_string_literal: true

RSpec.describe HomeController do
  describe "#index" do
    it "renders the built-in home page" do
      get root_path

      expect(response.body).to include "tagline"
    end

    context "with products from open shops" do
      let(:shop) { create(:distributor_enterprise, with_payment_and_shipping: true) }
      let(:product) { create(:product, name: "Navel Oranges") }

      let!(:order_cycle) {
        create(:simple_order_cycle, distributors: [shop], variants: [product.variants.first])
      }

      before { Rails.cache.clear }

      it "lists them, each linking to the shop that sells it", feature: :home_products do
        get root_path

        expect(response.body).to include "Available now"
        expect(response.body).to include "Navel Oranges"
        expect(response.body).to include enterprise_shop_path(shop, product: product.id)
      end

      it "opens with the marketplace hero and how it works", feature: :home_products do
        get root_path

        expect(response.body).to include 'id="origin-hero"'
        expect(response.body).to include "Oranges from the tree"
        expect(response.body).to include 'id="origin-steps"'
        expect(response.body).not_to include 'id="tagline"'
      end

      it "offers a filter by country of origin", feature: :home_products do
        italy = Spree::Country.find_by(iso: "IT") || create(:country, iso: "IT", name: "Italy")
        italian_producer = create(:supplier_enterprise)
        italian_producer.address.update_columns(country_id: italy.id)
        mozzarella = create(:product, name: "Mozzarella", enterprise_id: italian_producer.id)
        order_cycle.exchanges.outgoing.first.variants << mozzarella.variants.first

        get root_path

        expect(response.body).to include "All countries"
        expect(response.body).to include root_path(origin: "IT", anchor: "home-products")

        get root_path(origin: "it")

        expect(response.body).to include "Mozzarella"
        expect(response.body).not_to include "Navel Oranges"
      end

      it "ignores an origin that isn't a country code", feature: :home_products do
        get root_path(origin: "<script>")

        expect(response).to have_http_status :ok
        expect(response.body).to include "Navel Oranges"
      end

      it "doesn't list them while the feature is off" do
        get root_path

        expect(response.body).not_to include "Navel Oranges"
      end
    end

    context "with the home products feature on but nothing on sale", feature: :home_products do
      it "leaves out the products section" do
        get root_path

        expect(response.body).to include "tagline"
        expect(response.body).not_to include "Available now"
      end
    end

    context "with an external home page configured" do
      let(:url) { "https://cms.example.com/home/" }

      before do
        Rails.cache.clear
        ContentConfig.home_page_url = url
      end

      it "renders the built-in page until the content is available" do
        get root_path

        expect(response.body).to include "tagline"
        expect(ExternalPageJob).to have_been_enqueued.with(url)
      end

      it "renders the external content within our layout" do
        stub_request(:get, url).to_return(
          body: <<~HTML
            <html>
              <head><style id="wp-block-columns-inline-css">.wp-block-columns{}</style></head>
              <body><div class="entry-content"><h1>Marketplace</h1></div></body>
            </html>
          HTML
        )
        ExternalPageJob.perform_now

        get root_path

        expect(response.body).to include "<h1>Marketplace</h1>"
        expect(response.body).to include ".wp-block-columns{}"
        expect(response.body).not_to include "tagline"
        expect(response.body).to include "ofn-logo-footer" # our own layout
      end
    end
  end

  context "#unauthorized" do
    it "renders the unauthorized template" do
      get "/unauthorized"

      expect(response).to have_http_status :unauthorized
      expect(response).to render_template("shared/unauthorized", layout: 'darkswarm')
    end
  end
end
