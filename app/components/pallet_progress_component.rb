# frozen_string_literal: true

# Shows how full the shared pallet of an order cycle is, and whether the delivery is confirmed
# (feature: pallet_progress). The compact version fits in a product tile.
class PalletProgressComponent < ViewComponent::Base
  # explain: false leaves out the sentence on how pallets work, for lists that explain it once.
  def initialize(progress:, compact: false, explain: true)
    @progress = progress
    @compact = compact
    @explain = explain
  end

  def render?
    progress.tracked?
  end

  private

  attr_reader :progress, :compact, :explain

  def percent(share)
    (share * 100).round.to_i
  end

  def display_percent(share)
    helpers.number_to_percentage(percent(share), precision: 0)
  end

  def display_weight(weight)
    t("components.pallet_progress.kg", weight: helpers.number_with_delimiter(weight.round.to_i))
  end

  def title
    key = compact ? "title_short" : "title"
    return t("components.pallet_progress.#{key}") unless progress.name

    t("components.pallet_progress.#{key}_named", name: progress.name)
  end

  def status
    if progress.confirmed?
      t("components.pallet_progress.confirmed")
    elsif progress.minimum?
      key = compact ? "to_confirm_short" : "to_confirm"
      t("components.pallet_progress.#{key}", weight: display_weight(progress.weight_to_confirm))
    end
  end

  def detail
    t("components.pallet_progress.detail", ordered: display_weight(progress.ordered_weight),
                                           capacity: display_weight(progress.capacity))
  end

  def explanation
    if progress.minimum?
      t("components.pallet_progress.explanation_with_minimum",
        minimum: display_percent(progress.minimum_fill))
    else
      t("components.pallet_progress.explanation")
    end
  end

  def bar_label
    t("components.pallet_progress.bar_label", fill: display_percent(progress.fill))
  end
end
