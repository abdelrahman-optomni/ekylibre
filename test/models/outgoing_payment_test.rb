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
# == Table: outgoing_payments
#
#  accounted_at      :datetime
#  affair_id         :integer(4)
#  amount            :decimal(19, 4)   default(0.0), not null
#  bank_check_number :string
#  cash_id           :integer(4)       not null
#  created_at        :datetime         not null
#  creator_id        :integer(4)
#  currency          :string           not null
#  custom_fields     :jsonb
#  delivered         :boolean          default(FALSE), not null
#  downpayment       :boolean          default(FALSE), not null
#  id                :integer(4)       not null, primary key
#  journal_entry_id  :integer(4)
#  list_id           :integer(4)
#  lock_version      :integer(4)       default(0), not null
#  mode_id           :integer(4)       not null
#  number            :string
#  paid_at           :datetime
#  payee_id          :integer(4)       not null
#  position          :integer(4)
#  responsible_id    :integer(4)       not null
#  to_bank_at        :datetime         not null
#  type              :string
#  updated_at        :datetime         not null
#  updater_id        :integer(4)
#
require 'test_helper'

class OutgoingPaymentTest < Ekylibre::Testing::ApplicationTestCase::WithFixtures
  # Add tests here...

  test "can't create or edit if bank at is during an opened financial year exchange" do
    FinancialYear.delete_all
    fy = create(:financial_year, year: 2021)
    create(:financial_year_exchange, :opened, financial_year: fy, started_on: '2021-01-01', stopped_on: '2021-02-01')
    op = build(:outgoing_payment, at: '2021-01-15')
    assert_not op.valid?

    op.to_bank_at = '2021-02-15'.to_date
    assert op.valid?
  end
end
