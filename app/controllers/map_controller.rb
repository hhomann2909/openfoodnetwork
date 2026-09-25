# frozen_string_literal: true

class MapController < BaseController
  layout 'darkswarm'

  def index
    return unless OpenFoodNetwork::FeatureToggle.enabled?(:origin_map, spree_current_user)

    @origin_map = OriginMapService.new.as_json
    render :origin
  end
end
