class CreatePlanningScenarios < ActiveRecord::Migration
  def change
    unless table_exists?(:planning_scenarios)
      create_table :planning_scenarios do |t|
        t.string :name
        t.string :description
        t.references :campaign, index: true, foreign_key: true
        t.decimal :area
        t.integer :creator_id
        t.integer :updater_id
        t.timestamps null: false
      end
    end
  end
end
