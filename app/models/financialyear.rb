# == Schema Information
# Schema version: 20080819191919
#
# Table name: financialyears
#
#  id           :integer       not null, primary key
#  code         :string(12)    not null
#  nature_id    :integer       not null
#  closed       :boolean       not null
#  started_on   :date          not null
#  stopped_on   :date          not null
#  written_on   :date          not null
#  debit        :decimal(16, 2 default(0.0), not null
#  credit       :decimal(16, 2 default(0.0), not null
#  position     :integer       not null
#  company_id   :integer       not null
#  created_at   :datetime      not null
#  updated_at   :datetime      not null
#  created_by   :integer       
#  updated_by   :integer       
#  lock_version :integer       default(0), not null
#

class Financialyear < ActiveRecord::Base
  validates_uniqueness_of [:started_on, :stopped_on]

before_validation_on_create :validate_period
before_create :validate_date

def validate_period
  raise "Incompatible period." unless self.started_on < self.stopped_on
end

def validate_date
 period = JournalPeriod.find_by_stopped_on(:first, :order=>"DESC")  
 raise "The date of beginning of exercise is invalid." unless self.started_on > period.stopped_on 
end

# When a financial year is closed, all the matching journals are closed too. 
def close(date)
  self.update_attribute(stopped_on,date)
  self.update_attribute(closed, true)
  periods = JournalPeriod.find(:all, :conditions=>["financialyear_id = ?", self.id])
  periods.each do |period|
    journal = Journal.find(period.journal_id)
    journal.close(date)
    end
end


end
