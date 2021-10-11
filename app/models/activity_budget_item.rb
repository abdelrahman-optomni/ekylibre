# frozen_string_literal: true

# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2014 Brice Texier, David Joulin
# Copyright (C) 2015-2021 Ekylibre SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: activity_budget_items
#
#  activity_budget_id :integer          not null
#  amount             :decimal(19, 4)   default(0.0)
#  computation_method :string           not null
#  created_at         :datetime         not null
#  creator_id         :integer
#  currency           :string           not null
#  direction          :string           not null
#  id                 :integer          not null, primary key
#  lock_version       :integer          default(0), not null
#  quantity           :decimal(19, 4)   default(0.0)
#  unit_amount        :decimal(19, 4)   default(0.0)
#  unit_currency      :string           not null
#  unit_population    :decimal(19, 4)
#  updated_at         :datetime         not null
#  updater_id         :integer
#  variant_id         :integer
#  variant_indicator  :string
#  variant_unit       :string
#

class ActivityBudgetItem < ApplicationRecord
  refers_to :currency
  enumerize :direction, in: %i[revenue expense], predicates: true
  enumerize :computation_method, in: %i[per_campaign per_production per_working_unit], default: :per_working_unit, predicates: true
  # refers_to :variant_indicator, class_name: 'Indicator' # in: Activity.support_variant_indicator.values
  # refers_to :variant_unit, class_name: 'Unit'

  belongs_to :activity_budget, inverse_of: :items
  has_one :activity, through: :activity_budget
  has_one :campaign, through: :activity_budget
  belongs_to :variant, class_name: 'ProductNatureVariant'
  has_many :productions, through: :activity
  belongs_to :product_parameter, class_name: InterventionTemplate::ProductParameter

  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :amount, :quantity, :unit_amount, :unit_population, numericality: { greater_than: -1_000_000_000_000_000, less_than: 1_000_000_000_000_000 }, allow_blank: true
  validates :activity_budget, :computation_method, :currency, :direction, presence: true
  validates :unit_currency, presence: true, length: { maximum: 500 }
  validates :variant_indicator, :variant_unit, length: { maximum: 500 }, allow_blank: true
  # ]VALIDATORS]
  validates :variant, presence: true
  validates :unit_amount, presence: { message: :invalid }
  validates :currency, match: { with: :activity_budget }

  delegate :size_indicator, :size_unit, to: :activity
  delegate :currency, to: :activity_budget, prefix: true
  delegate :name, to: :variant, prefix: true

  scope :revenues, -> { where(direction: :revenue).includes(:variant) }
  scope :expenses, -> { where(direction: :expense).includes(:variant) }

  before_validation do
    self.unit_currency = Preference[:currency] if unit_currency.blank?
    self.currency = unit_currency if currency.blank?
  end

  validate do
    # ???: Why do we even have both if we check that they're always equals??
    if currency && unit_currency
      errors.add(:currency, :invalid) if currency != unit_currency
    end
  end

  after_validation do
    self.amount = unit_amount * quantity * coefficient if unit_amount.present?
  end

  # Computes the coefficient to use for amount computation
  def coefficient
    return 0 unless activity_budget
    if per_production?
      return activity_budget.productions_count || 0
    elsif per_working_unit?
      return activity_budget.productions_size || 0
    end

    1
  end

  # Duplicate an item in the same budget by default. Each attribute are
  # overwritable.
  def duplicate!(updates = {})
    new_attributes = %i[
      activity_budget amount computation_method currency direction
      quantity unit_amount unit_currency unit_population variant
      variant_indicator variant_unit
    ].each_with_object({}) do |attr, h|
      h[attr] = send(attr)
      h
    end.merge(updates)
    self.class.create!(new_attributes)
  end

  def unit
    Onoma::Unit.find(variant_unit)
  end

  def total_quantity
    quantity * coefficient
  end

  def direct_expenses_amount
    activity_budget.expenses_amount * expenses_distribution_key
  end

  def loan_repayments_amount
    activity_budget.loan_repayments_amount * expenses_distribution_key
  end

  def indirect_expenses_amount
    activity_budget.indirect_expenses_amount * expenses_distribution_key
  end

  # Direct and indirect expenses amount
  def total_expenses_amount
    a = activity_budget.expenses_amount + activity_budget.loan_repayments_amount
    a += activity_budget.indirect_expenses_amount if activity.main?
    a * expenses_distribution_key
  end

  def expenses_distribution_key
    @expenses_distribution_key ||= amount / activity_budget.revenues.sum(:amount)
  end

  # Computes with direct expenses and indirect expenses for main activities
  # No commercialization_threshold for auxiliary activities
  def commercialization_threshold
    total_expenses_amount
  end

  def raw_margin
    amount - direct_expenses_amount - loan_repayments_amount
  end

  # Cmpute net margin
  def net_margin
    return nil if activity.auxiliary?

    amount - total_expenses_amount
  end

  # Computes real quantity based on intervention outputs
  # Same grandeur as quantity
  def real_quantity
    unless @real_quantity
      # Get quantities from intervention outputs
      population = InterventionOutput.where(
        variant: self.variant,
        group_id: InterventionTarget.where(
          product_id: activity.productions.of_campaign(campaign).select(:support_id)
        ).select(:group_id)
      ).sum(:quantity_population)
      # Convert to unit of item
      if self.variant_indicator && population
        @real_quantity = (self.variant.get(self.variant_indicator) * population).in(variant_unit).to_d
      else
        @real_quantity = 0
      end
      if per_working_unit? && activity_budget.productions_size != 0
        @real_quantity /= activity_budget.productions_size
      elsif per_production? && activity_budget.productions_count != 0
        @real_quantity /= activity_budget.productions_count
      end
    end
    @real_quantity
  end

  def real_total_expenses_amount
    real_direct_expenses_amount + real_loan_repayments_amount + real_indirect_expenses_amount
  end

  def real_direct_expenses_amount
    # TODO: Add computation
    rdea = 5555
    # Without harvest, only zero.....
    rdea * real_expenses_distribution_key
  end

  def real_loan_repayments_amount
    activity_budget.loan_repayments_amount(on: Date.today) * real_expenses_distribution_key
  end

  def real_indirect_expenses_amount
    activity_budget.real_indirect_expenses_amount * real_expenses_distribution_key
  end

  def real_expenses_distribution_key
    unless @real_expenses_distribution_key
      total = activity_budget.revenues.map(&:real_amount).sum
      if total.zero?
        @real_expenses_distribution_key = 0
      else
        @real_expenses_distribution_key = real_amount / activity_budget.revenues.map(&:real_amount).sum
      end
    end
    @real_expenses_distribution_key
  end

  def real_total_quantity
    real_quantity * coefficient
  end

  def real_unit_amount
    # What to take? CUMP, budget, last sale, total_weighted_average
    unit_amount
  end

  def real_amount
    real_unit_amount * real_quantity * coefficient
  end

  def real_raw_margin
    real_amount - real_direct_expenses_amount - real_loan_repayments_amount
  end

  def real_commercialization_threshold
    real_total_expenses_amount
  end

  def real_net_margin
    return nil if activity.auxiliary?

    real_amount - real_total_expenses_amount
  end
end
