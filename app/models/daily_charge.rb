# frozen_string_literal: true

class DailyCharge < ApplicationRecord
  belongs_to :activity_production, class_name: ActivityProduction, required: true
  belongs_to :product_parameter, class_name: InterventionTemplate::ProductParameter, required: true, foreign_key: :intervention_template_product_parameter_id
  belongs_to :activity
  validates :reference_date, :product_type, :quantity, :area, presence: true

  scope :of_type, ->(type) { where(product_general_type: type) }

  scope :of_activity, lambda { |activity|
    joins(:activity_production).where(activity_productions: { activity_id: activity }) if activity.present?
  }

  scope :between_date, lambda { |from, to|
    where(reference_date: from..to) if from.present? && to.present?
  }

  def self.of_activity_production(activity_production)
    where(activity_production: activity_production) if activity_production.present?
  end

  def quantity_with_unit
    if %w[tool doer].include?(product_general_type)
      quantity.round(1).in_hour.localize(precision: 1)
    elsif product_parameter.unit == 'unit'
      "#{quantity}  #{:unit.tl}"
    else
      quantity.round(1).in(Onoma::Unit[product_parameter.unit.gsub(/_per_.*/, '')].symbol).l(precision: 1)
    end
  end

  def available_quantity
    if %w[tool doer].include?(product_general_type)
      product_parameter.product_nature.variants.map(&:current_stock).sum.round(2)
    elsif product_general_type == 'input'
      "#{product_parameter.product_nature_variant.current_stock.round(1).l(precision: 1)} #{product_parameter.product_nature_variant.unit_name}".gsub(',', '.')
    end
  end
end
