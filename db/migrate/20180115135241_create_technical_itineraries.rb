class CreateTechnicalItineraries < ActiveRecord::Migration
  def change
    unless table_exists?(:technical_itineraries)
      create_table :technical_itineraries do |t|
        t.string :name
        t.references :campaign, index: true, foreign_key: true
        t.references :activity, index: true, foreign_key: true
        t.string :description
        t.timestamps null: false
      end
    end
  end
end
