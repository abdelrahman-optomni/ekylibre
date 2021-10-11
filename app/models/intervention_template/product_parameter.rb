# frozen_string_literal: true

# Relation
class InterventionTemplate < ApplicationRecord
  class ProductParameter < ApplicationRecord
    self.table_name = "intervention_template_product_parameters"

    belongs_to :intervention_template, class_name: InterventionTemplate, foreign_key: :intervention_template_id
    belongs_to :product_nature, class_name: ProductNature, foreign_key: :product_nature_id
    belongs_to :product_nature_variant, class_name: ProductNatureVariant, foreign_key: :product_nature_variant_id

    has_many :daily_charges, class_name: DailyCharge, dependent: :destroy, foreign_key: :intervention_template_product_parameter_id

    # Validation
    validates :quantity, presence: true
    validates :product_nature, presence: true, unless: :product_nature_variant_id?
    validates :product_nature_variant, presence: true, unless: :product_nature_id?
    validates :unit, presence: true, if: :quantitiy_positive?, unless: :procedure_is_plant?

    attr_accessor :product_name

    # Need to access product_name in js
    def attributes
      super.merge(product_name: '')
    end

    def quantitiy_positive?
      quantity || 0 > 0
    end

    def measure
      Measure.new(quantity, procedure_unit)
    end

    def unit_symbol
      Onoma::Unit[unit]&.symbol
    end

    def unit_per_area?
      %i[volume_area_density mass_area_density surface_area_density].include? Onoma::Unit[unit]&.dimension
    end

    def find_general_product_type
      return :tool if has_product_parameter?(intervention_template.tools)
      return :doer if has_product_parameter?(intervention_template.doers)
      return :input if has_product_parameter?(intervention_template.inputs)
      return :output if has_product_parameter?(intervention_template.outputs)
    end

    def has_product_parameter?(relation)
      relation
        .where(id: id)
        .any?
    end

    def quantity_in_unit(area)
      if unit == 'unit'
        return self.quantity * area
      end

      quantity = self.quantity
        .in(unit)
        .convert(unit.gsub(/_per_.*/, '') + '_per_hectare')
        .to_f

      quantity * area
    end

    # return global quantity in unit @Measure
    def global_quantity_in_unit(area_in_hectare)
      global_quantity = nil
      # if tool or doer
      if %i[tool doer].include?(self.find_general_product_type)
        global_quantity =  intervention_template.time_per_hectare * self.quantity * area_in_hectare
        global_quantity.in(:hours).round(2)
      end
      # if input or output
      if %i[input output].include?(self.find_general_product_type)
        if self.unit_per_area?
          short_unit = unit.split('_per_').first
          puts short_unit.inspect.yellow
          area_unit = unit.split('_per_').last
          puts area_unit.inspect.yellow
          area_coef = Measure.new(1.0, area_unit.to_sym).convert(:hectare).to_f
          puts area_coef.inspect.yellow
          global_quantity = (self.quantity * (area_in_hectare / area_coef)).in(short_unit.to_sym).round(2)
          puts global_quantity.inspect.green
        elsif self.unit == 'unit'
          global_quantity = (self.quantity * area_in_hectare).in(:unit).round(2)
        else
          product_parameter.quantity.in(product_parameter.unit.to_sym)
        end
      end
      global_quantity
    end

    def quantity_with_unit
      if is_input_or_output
        if unit == "population"
          "#{quantity} #{:unit.tl}"
        else
          measure.l(precision: 1)
        end
      else
        quantity.l(precision: 1)
      end
    end

    def is_doer_or_tool
      %i[doer tool].include?(find_general_product_type)
    end

    private

      def procedure_is_plant?
        procedure['type'] == 'plant'
      end

      # unit correspond to handler name in this model
      def procedure_handler
        return if is_doer_or_tool

        intervention_template.procedure
                              .parameters
                              .find { |p| p.name == procedure['type'].to_sym }
                              .handlers
                              .find { |h| h.name == unit.to_sym }
      end

      def procedure_unit
        handler = procedure_handler
        return nil if handler.nil?

        handler.unit.name
      end

      def is_input_or_output
        %i[input output].include?(find_general_product_type)
      end
  end
end
