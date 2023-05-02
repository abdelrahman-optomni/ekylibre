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
# == Table: technical_workflow_procedure_items
#
#  actor_reference                 :string
#  article_reference               :string
#  procedure_item_reference        :string
#  procedure_reference             :string           not null
#  quantity                        :decimal(19, 4)
#  reference_name                  :string           not null, primary key
#  technical_workflow_procedure_id :string           not null
#  unit                            :string
#
class TechnicalWorkflowProcedureItem < LexiconRecord
  include Lexiconable
  belongs_to :procedure, class_name: 'TechnicalWorkflowProcedure', foreign_key: :technical_workflow_procedure_id
  composed_of :value, class_name: 'Measure', mapping: [%w[quantity to_d], %w[unit unit]]
end
