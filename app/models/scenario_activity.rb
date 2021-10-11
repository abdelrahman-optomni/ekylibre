# frozen_string_literal: true

class ScenarioActivity < ApplicationRecord
  self.table_name = "planning_scenario_activities"
  belongs_to :scenario, class_name: Scenario, foreign_key: :planning_scenario_id
  belongs_to :activity, class_name: Activity, foreign_key: :activity_id
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id'
  has_many :plots, class_name: ScenarioActivity::Plot, foreign_key: :planning_scenario_activity_id, dependent: :destroy
  accepts_nested_attributes_for :plots, allow_destroy: true

  validates :activity, presence: true

  def activity_name
    activity.name
  end
end
