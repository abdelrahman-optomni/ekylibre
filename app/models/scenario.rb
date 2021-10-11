# frozen_string_literal: true

class Scenario < ApplicationRecord
  self.table_name = "planning_scenarios"

  validates :name, :campaign, presence: true

  belongs_to :campaign, class_name: Campaign, foreign_key: :campaign_id
  has_many :scenario_activities, class_name: ScenarioActivity, foreign_key: :planning_scenario_id, dependent: :destroy

  accepts_nested_attributes_for :scenario_activities
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id'

  def generate_daily_charges
    plots = get_plots
    daily_charges = []
    plots.each do |plot|
      daily_charges.concat(plot.generate_daily_charges)
    end
    daily_charges
  end

  def rotation_area
    plots = get_plots.includes(:batch)
    plots.sum(&:total_area)
  end

  def human_rotation_area
    rotation_area.in(:hectare).l(precision: 0)
  end

  private

    # rubocop:disable Naming/AccessorMethodName
    def get_plots
      ScenarioActivity::Plot.of_scenario(self)
    end
  # rubocop:enable Naming/AccessorMethodName
end
