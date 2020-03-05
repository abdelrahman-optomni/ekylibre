module Backend
  class RegisteredPhytosanitaryUsagesController < Backend::BaseController
    DIMENSIONS_UNIT = { net_volume: :liter, net_mass: :kilogram, mass_area_density: :kilogram_per_hectare, volume_area_density: :liter_per_hectare }.freeze
    AREA_DIMENSIONS = { net_volume: :liter_per_hectare, net_mass: :kilogram_per_hectare }.freeze

    unroll :crop_label_fra, :target_name_label_fra

    def filter_usages
      return render json: { disable: :maaid_not_provided.tl, clear: true } unless (variant = Product.find(params[:filter_id]).variant) && (variant.imported_from == "Lexicon")
      registered_pp = RegisteredPhytosanitaryProduct.find_by_reference_name(variant.reference_name)
      retrieved_ids = params[:retrieved_ids].uniq.reject(&:blank?)
      scopes = { of_product: registered_pp.france_maaid }
      if retrieved_ids.any?
        cultivation_varieties = Product.find(retrieved_ids).map { |p| p.activity&.cultivation_variety }.uniq.compact
        scopes[:of_variety] = cultivation_varieties
      end
      clear = if params[:selected_value].present?
                scoped_collection = RegisteredPhytosanitaryUsage.send(:of_product, scopes[:of_product])
                scoped_collection = scoped_collection.send(:of_variety, *scopes[:of_variety]) if scopes[:of_variety]
                scoped_collection.pluck(:id).exclude?(params[:selected_value])
              else
                true
              end
      render json: { scope_url: unroll_backend_registered_phytosanitary_usages_path(scope: scopes), clear: clear }
    end

    def get_usage_infos
      usage_id = params[:id]
      usage = RegisteredPhytosanitaryUsage.find(usage_id)
      usage_dataset = compute_dataset(usage)
      allowed_factors = compute_allowed_factors(usage)
      usage_application = compute_usage_application(usage, params[:targets_data], params[:intervention_id])
      authorizations = compute_authorization(usage_application, :usage_application)

      render json: { usage_infos: usage_dataset, usage_application: usage_application, allowed_factors: allowed_factors, authorizations: authorizations }
    end

    def dose_validations
      id = params[:id]
      product_id = params[:product_id]
      quantity = params[:quantity]
      dimension = params[:dimension]
      targets_data = params[:targets_data]

      usage = RegisteredPhytosanitaryUsage.find(id)
      product = Product.find(product_id)

      service = RegisteredPhytosanitaryUsageDoseComputation.new

      dose_validation = service.validate_dose(usage, product, quantity.to_f, dimension, targets_data)
      authorizations = compute_authorization(dose_validation, :dose_validation)

      return render(json: { dose_validation: dose_validation, authorizations: authorizations })
    end

    private

      def compute_allowed_factors(usage)
        { "allowed-entry" => usage.product.in_field_reentry_delay, "allowed-harvest" => usage.pre_harvest_delay }
      end

      def compute_dataset(usage)
        {
          state: usage.decision_date ? "#{usage.state} (#{usage.decision_date.l})" : usage.state,
          maximum_dose: usage.dose_quantity ? "#{usage.dose_quantity} #{usage.dose_unit_name}" : nil,
          untreated_buffer_aquatic: usage.untreated_buffer_aquatic ? "#{usage.untreated_buffer_aquatic} m" : nil,
          re_entry_interval: usage.product.in_field_reentry_delay ? "#{usage.product.in_field_reentry_delay} h" : nil,
          applications_count: usage.applications_count,
          untreated_buffer_arthropod: usage.untreated_buffer_arthropod ? "#{usage.untreated_buffer_arthropod} m" : nil,
          pre_harvest_delay: usage.pre_harvest_delay ? "#{usage.pre_harvest_delay} j" : nil,
          development_stage: compute_development_stage(usage),
          untreated_buffer_plants: usage.untreated_buffer_plants ? "#{usage.untreated_buffer_plants} m" : nil,
          usage_conditions: usage.usage_conditions ? usage.usage_conditions.gsub('//', '<br/>').html_safe : nil
        }
      end

      def compute_development_stage(usage)
        return nil if usage.development_stage_min.nil? && usage.development_stage_max.nil?

        if usage.development_stage_min && usage.development_stage_max == nil
          "Min : #{usage.development_stage_min}"
        elsif usage.development_stage_min == nil && usage.development_stage_max
          "Max : #{usage.development_stage_max}"
        else
          "#{usage.development_stage_min} #{usage.development_stage_max}"
        end
      end

      def compute_usage_application(usage, targets_data, intervention_id)
        return { none: ''} unless targets_data

        maaid = usage.product.france_maaid

        applications_on_targets = targets_data.values.map do |target_info|
          interventions = Product.find(target_info[:id]).activity_production.interventions.of_nature(:spraying).with_maaids(maaid)
          interventions = interventions.where.not(id: intervention_id) if intervention_id.present?
          interventions.map do |intervention|
            intervention.targets.map(&:working_zone).select { |zone| Charta.new_geometry(target_info[:shape]).intersects?(zone) }.count
          end
        end.flatten.sum

        compare_applications_count(usage, applications_on_targets)
      end

      def compare_applications_count(usage, usage_applications)
        return { none: ''} if usage.applications_count.nil? || usage_applications.nil?

        applications = usage_applications + 1
        if applications < usage.applications_count
          { go: :applications_count_less_than_max.tl }
        elsif applications == usage.applications_count
          { caution: :applications_count_equal_to_max.tl }
        else
          { stop: :applications_count_bigger_than_max.tl }
        end
      end

      def compute_authorization(lights_hash, authorization_name)
        if %i[go caution].include?(lights_hash.keys.first)
          { authorization_name => 'allowed' }
        elsif %i[none].include?(lights_hash.keys.first)
          { authorization_name => 'unknown' }
        else
          { authorization_name => 'forbidden' }
        end
      end
  end
end