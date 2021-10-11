# frozen_string_literal: true

module TechnicalItineraries
  module Itk
    class CreateBudget
      attr_reader :activity, :campaign

      def initialize(activity:, scenario:, campaign:)
        @activity = activity
        @scenario = scenario
        @campaign = campaign
        @logger ||= Logger.new(File.join(Rails.root, 'log', "itk-#{@campaign.name}-#{Ekylibre::Tenant.current.to_s}.log"))
      end

      def create_plot_activity_for_scenario
        # check if activity has ITK
        at = ActivityTactic.find_by(activity: @activity, campaign: @campaign, default: true)
        ti = TechnicalItinerary.find_by(activity_tactic_id: at.id, activity: @activity, campaign: @campaign) if at
        if ti
          # compute default area with campaign, N-1 or N-2
          current_area = @activity.size_during(@campaign).to_f
          previous_area = (@campaign.preceding ? @activity.size_during(@campaign.preceding).to_f : 0.0)
          ante_previous_area = (@campaign.preceding&.preceding ? @activity.size_during(@campaign.preceding.preceding).to_f : 0.0)
          if current_area > 0.0
            area = current_area
          elsif previous_area > 0.0
            area = previous_area
          elsif ante_previous_area > 0.0
            area = ante_previous_area
          else
            area = 0.0
          end

          # link activity and scenario
          sa = ScenarioActivity.find_or_create_by(scenario: @scenario, activity: @activity)
          # create one plot for all activity
          sap = ScenarioActivity::Plot.find_or_initialize_by(scenario_activity: sa)
          sap.technical_itinerary = ti
          sap.area = area
          sap.planned_at = at.planned_on
          sap.batch_planting = false
          sap.save!
          @logger.info("-----------------Scenario created for #{@activity.name}")
        else
          @logger.error("-----------------No scenario created because no TI exist for #{@activity.name}")
        end
      end

      def create_budget_from_itk
        activity_tactic = ActivityTactic.find_by(campaign: @campaign, activity: @activity, default: true)
        technical_itinerary = TechnicalItinerary.find_by(tactic: activity_tactic, campaign: @campaign, activity: @activity) if activity_tactic
        unless technical_itinerary
          @logger.error("No technical_itinerary found")
          return nil
        end
        # find corresponding budget and remove all previous items
        activity_budget = ActivityBudget.find_or_create_by!(activity_id: @activity.id, campaign_id: @campaign.id, technical_itinerary_id: technical_itinerary.id)
        activity_budget.items.destroy_all if activity_budget&.items&.any?
        # find ti from activity and campaing and set new ti

        activity_budget.nature = "compute_from_itk"
        activity_budget.save!

        scenario_activity = ScenarioActivity.find_by(scenario: @scenario, activity: @activity)
        if scenario_activity
          scenario_activity.plots.each do |sap|
            dc = sap.generate_daily_charges
            dc.each do |daily_charge|
              if %w[input output].include?(daily_charge.product_general_type)
                @logger.info("Create budget item for #{daily_charge.inspect}")
                create_budget_item_from_itk(activity_budget, daily_charge)
              end
            end
          end
        else
          @logger.error("No Budget item created because no scenario activity exist for #{@activity.name}")
        end
      end

      def create_budget_item_from_itk(activity_budget, daily_charge)
        used_on = daily_charge.reference_date
        # quantity = daily_charge.quantity # in population of variant
        area_in_hectare = daily_charge.area # in hectare
        itpp = InterventionTemplate::ProductParameter.find_by(id: daily_charge.intervention_template_product_parameter_id)
        variant = itpp.product_nature_variant

        # get quantity, unit and computation method return {computation_method: ,quantity: ,indicator: , unit: ,unit_amount:}
        qup = find_quantity_unit_price(itpp, variant, area_in_hectare)
        # create budget_item
        if variant && used_on && itpp && qup.presence
          activity_budget_item = activity_budget.items.find_or_initialize_by(variant_id: variant.id, used_on: used_on)
          activity_budget_item.direction = qup[:direction]
          activity_budget_item.variant_unit = qup[:unit]
          activity_budget_item.product_parameter_id = itpp.id
          activity_budget_item.variant_indicator = qup[:indicator]
          activity_budget_item.computation_method = qup[:computation_method]
          activity_budget_item.quantity = qup[:quantity] || 1
          activity_budget_item.unit_amount = qup[:unit_amount] || 0.0
          activity_budget_item.save!
          @logger.info("budget_item_from_itk created for #{variant.name}")
        else
          @logger.error("budget_item_from_itk not created for #{variant.name}")
        end
      end

      def find_quantity_unit_price(itpp, variant, area_in_hectare)
        # for input only
        response = {}
        quantity_in_unit = itpp.global_quantity_in_unit(area_in_hectare)
        @logger.info("Quantity in unit is #{quantity_in_unit.inspect}")

        if %i[input].include?(itpp.find_general_product_type)
          response[:computation_method] = :per_working_unit
          response[:direction] = :expense
          catalog = Catalog.where(usage: %w[cost purchase stock])
        elsif %i[output].include?(itpp.find_general_product_type)
          response[:computation_method] = :per_working_unit
          response[:direction] = :revenue
          catalog = Catalog.where(usage: %w[cost sale])
        end

        if catalog
          response[:quantity] = (quantity_in_unit.value / area_in_hectare).round(2)
          @logger.info("Quantity per hectare is #{response[:quantity]}")
          last_catalog_item = CatalogItem.find_by(variant_id: variant.id, catalog_id: catalog.pluck(:id))
          if last_catalog_item
            @logger.info("last_catalog_item found for #{variant.name} | ID : #{last_catalog_item.id} | amount : #{last_catalog_item.amount} | unit : amount : #{last_catalog_item.unit.reference_name}")
            unit_amount_with_indicator = last_catalog_item.unit_amount_in_target_unit(quantity_in_unit.unit)
            response[:unit_amount] = unit_amount_with_indicator[:unit_amount]
            response[:unit] = unit_amount_with_indicator[:unit]
            response[:indicator] = unit_amount_with_indicator[:indicator]
            @logger.info("last_catalog_item conversion for #{variant.name} | unit_amount : #{response[:unit_amount]} - unit : #{response[:unit]} - indicator : #{response[:indicator]}")
          else
            MasterPrice.where(reference_article_name: variant.reference_name).each do |v_price|
              CatalogItem.import_from_lexicon(v_price.reference_name)
            end
            created_catalog_item = CatalogItem.find_by(variant_id: variant.id, catalog_id: catalog.pluck(:id))
            if created_catalog_item
              unit_amount_with_indicator = created_catalog_item.unit_amount_in_target_unit(quantity_in_unit.unit)
              response[:unit_amount] = unit_amount_with_indicator[:unit_amount]
              response[:unit] = unit_amount_with_indicator[:unit]
              response[:indicator] = unit_amount_with_indicator[:indicator]
              @logger.info("price created for #{variant.name} | unit_amount : #{response[:unit_amount]} - unit : #{response[:unit]} - indicator : #{response[:indicator]}")
            else
              @logger.error("No price exist for #{variant.name}")
            end
          end
        end
        response
      end

    end
  end
end
