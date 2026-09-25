# frozen_string_literal: true

class HomeController < BaseController
  layout 'darkswarm'

  helper_method :home_product_offers

  def index
    @external_page = CachedExternalPage.fetch(ContentConfig.home_page_url)
    return if @external_page

    return unless ContentConfig.home_show_stats

    @num_distributors = cached_count('distributors', Enterprise.is_distributor.activated.visible)
    @num_producers = cached_count('producers', Enterprise.is_primary_producer.activated.visible)
    @num_orders = cached_count('orders', Spree::Order.complete)
    @num_users = cached_count(
      'users', Spree::Order.complete.select('DISTINCT spree_orders.user_id')
    )
  end

  def sell; end

  def unauthorized
    render 'shared/unauthorized', status: :unauthorized
  end

  private

  # Called from inside the view's fragment cache, so the shops are only queried on a cache miss.
  def home_product_offers
    @home_product_offers ||= HomeProductsService.new.offers
  end

  # Cache the value of the query count
  def cached_count(statistic, query)
    CacheService.home_stats(statistic) do
      query.count
    end
  end
end
