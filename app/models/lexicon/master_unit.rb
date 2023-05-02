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
# == Table: master_units
#
#  a              :decimal(25, 10)
#  b              :decimal(25, 10)
#  d              :decimal(25, 10)
#  dimension      :string           not null
#  reference_name :string           not null, primary key
#  symbol         :string           not null
#  translation_id :string           not null
#

class MasterUnit < LexiconRecord
  include Lexiconable

  belongs_to :translation, class_name: 'MasterTranslation'
  scope :of_dimension, ->(dimension) { where(dimension: dimension.to_s) }
end
