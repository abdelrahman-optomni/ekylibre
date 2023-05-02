# frozen_string_literal: true

# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2014 Brice Texier, David Joulin
# Copyright (C) 2015-2023 Ekylibre SAS
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
# == Table: tax_declaration_item_parts
#
#  account_id              :integer(4)       not null
#  created_at              :datetime         not null
#  creator_id              :integer(4)
#  direction               :string           not null
#  id                      :integer(4)       not null, primary key
#  journal_entry_item_id   :integer(4)       not null
#  lock_version            :integer(4)       default(0), not null
#  pretax_amount           :decimal(19, 4)   not null
#  tax_amount              :decimal(19, 4)   not null
#  tax_declaration_item_id :integer(4)       not null
#  total_pretax_amount     :decimal(19, 4)   not null
#  total_tax_amount        :decimal(19, 4)   not null
#  updated_at              :datetime         not null
#  updater_id              :integer(4)
#
class TaxDeclarationItemPart < ApplicationRecord
  belongs_to :account
  belongs_to :tax_declaration_item
  belongs_to :journal_entry_item
  enumerize :direction, in: %i[deductible collected fixed_asset_deductible intracommunity_payable]

  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :account, :direction, :journal_entry_item, :tax_declaration_item, presence: true
  validates :pretax_amount, :tax_amount, :total_pretax_amount, :total_tax_amount, presence: true, numericality: { greater_than: -1_000_000_000_000_000, less_than: 1_000_000_000_000_000 }
  # ]VALIDATORS]
  validates :account, :tax_declaration_item, :journal_entry_item, presence: true
end
